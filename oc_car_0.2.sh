#!/bin/bash
#Version 0.2 / 27.03.2014 
#Abfrage, ob User gefunden werden konnte eingebunden
#Abfrage, ob gültige gpx Datei vorliegt
#Abfrage, ob Radius zwischen 0.1 und 10 liegt
#Version 0.1 / 26.03.2014
#Mail: ka.be.geo@gmail.com
#Aufruf des Scripts:
#z.B.:  Script   Inputfile Radius in km user
#       ./oc_car.sh route.gpx 1.5          ka_be
#Alle Parameter MÜSSEN angegeben werden!!!
#Eine Route kann man sich ohne Anmeldung z.B. bei openrouteservice.org/?lang=de# erzeugen und als gpx speichern 

#Für dieses Script müssen gpsbabel und BC installiert sein
#wenn sendemail installiert ist, kann eine Mail mit angehängter gpx versendet werden

#User ID ermitteln
UUID=$(curl "http://www.opencaching.de/okapi/services/users/by_username?username=$3&fields=uuid&consumer_key=8YV657YqzqDcVC3QC9wM" -s)

#Überprüfen der UserID
if [ ${UUID:0:5} == "{\"err" ]; then
  echo "User nicht gefunden! Bitte Aufrufparameter prüfen -> z.B. ./oc_car.sh route.gpx 1.5 ka_be" 
  exit
fi
echo "User wurde gefunden."

#Überprüfen der gpx Datei
if gpsbabel -i gpx -f $1 -o gpx -F - > /dev/null; then
    echo "GPX Datei ist gültig"
else
    echo "GPX Datei ist ungültig! Bitte Aufrufparameter prüfen -> z.B. ./oc_car.sh route.gpx 1.5 ka_be"
	exit
fi

#Überprüfen des Radius
if [ ${2} -gt 0 ]; then
    if [ ${2} -lt 11 ]; then
		echo "Radius ist ok"
	else
		echo "Radius muss zwischen 0.1 und 10 liegen! Bitte Aufrufparameter prüfen -> z.B. ./oc_car.sh route.gpx 1.5 ka_be"
		exit
	fi
else
    echo "Radius muss zwischen 0.1 und 10 liegen! Bitte Aufrufparameter prüfen -> z.B. ./oc_car.sh route.gpx 1.5 ka_be"
	exit
fi

# rechts 2 Zeichen abschneiden
UUID=${UUID%??}
# links 9 Zeichen abschneiden
UUID=${UUID#?????????}
echo
echo "Deine UserID ist "$UUID
echo
#Die ermittelte Route zuweisen, z.B. von openrouteservice.org/?lang=de#
input=$1 
#Die auszugebende Geocaching gpx Datei bestimmen -> Format (YYMMDD-HHMMSS)PQ.gpx
output=($(date "+%y%m%d-%H%M%S")PQ.gpx)

#error und distance sind Parameter für die Bearbeitung der Route und zum Festlegen der Koordinaten für die jeweilige
#Umkreissuche.
#circle ist die maximale breite des Korridors
#Bei einem Verhältniss error/circle ~1/4 und distance/circle ~ 5/4 ergibt dass eine mindest Abdeckung von ca. 2/3 von circle
error="0"$( echo "scale=2; $2 / 4" | bc )"k"      # Douglas-Peucker tolerance
distance="0"$(echo "scale=2; $2 / 4 * 5" | bc)"k"   # interpolation distance
circle=$2   # Suchradius in km

echo "Der max. Abstand zur festgelegten Route beträgt "$(echo "scale=3; $circle / 2" | bc)"km."
echo "Alle "$distance"m wird eine neue OC.de Abfrage durchgeführt."
echo "Zur Glättung der Route wird der Wert "$error"m genutzt."
echo
echo "Das kann jetzt ein paar Sekunden dauern..."

#gpsbabel zum Glätten und berechnen der Koordinaten für die jeweilige Umkreissuche
searchargs=$(
cat $input |
gpsbabel -i gpx -f - \
    -x simplify,crosstrack,error=$error \
         -o gpx -F - |
gpsbabel -i gpx -f - \
    -x interpolate,distance=$distance \
         -o csv -F - |
tr ',' ' ' |
awk '{printf("%.3f,%.3f|",$1,$2)}'

)

echo "An diesen Punkten wird mit einem Radius von "$circle"km nach OC Dosen gesucht:"
echo $searchargs
echo
echo "Das kann jetzt ein paar Sekunden dauern..."
echo
#Hier wird aus dem Format Lat,Lon|Lat,Lon -> Lat|Lon,Lat|Lon
b="$(echo "$searchargs" | sed 's/'\|'/'a'/g')"
c="$(echo "$b" | sed 's/'\,'/'\|'/g')"
d="$(echo "$c" | sed 's/'a'/'\,'/g')"

#Hier werden aus dem String die einzelnen Koordiantenpaare in ein Array geschriben
IFS=',' read -a array <<< "$d"

for index in "${!array[@]}"; do
echo -n
#echo "$index ${array[index]}"
done

#Variablen festlegen für die Fortschrittsanzeige
coords="${#array[@]}"
echo " %  - Listings"
prozent=0

#Hier finden die einzelnen Abfragen statt, der Consumer_key kann bei http://www.opencaching.de/okapi/signup.html besorgt werden 
for index in "${!array[@]}"; do
var1=$(curl "http://www.opencaching.de/okapi/services/caches/search/nearest?center=${array[index]}&radius=${circle}&consumer_key=8YV657YqzqDcVC3QC9wM" -s)
#Wenn weniger als 30 Zeichen zurückkommen, war in diesem Bereich keine Dose versteckt
if [ ${#var1} -lt 30 ]; then
var1=""
#Fortschritt
anzahl="$(echo "$alle" |wc -w)"
prozent=$(echo "scale=9;$prozent + 100 / $coords" | bc)
echo "$prozent % - $anzahl"
else
#Ansonsten den Ausgabestring bearbeiten
# rechts 16  Zeichen abschneiden
var1=${var1%????????????????}
# links 13 Zeichen abschneiden
var1=${var1#?????????????}
#Hier werden die " entfernt und das Komma gegen ein Leerzeichen getauscht 
a="$(echo "$var1" | sed 's/\"//g')"
b="$(echo "$a" | sed 's/'\,'/'\ '/g')"
b=$b" "

#In der Variable $alle werden  alle ermittelten OCcodes gespeichert
alle=$alle$b" "
alle=${alle%?}
#Fortschritt
anzahl="$(echo "$alle" |wc -w)"
prozent=$(echo "scale=9;$prozent + 100 / $coords" | bc)
echo "$prozent % - $anzahl"
fi
done

#Hier werden Duplikate aus dem String gefiltert
a="$(echo "$alle" | xargs -n1 | sort -u | xargs)"
echo -n "Gefunden Listings: " 
echo $a | wc -w

#Jetzt werden die | zwischen die OCcodes eingefügt und der Okapi Aufruf durchgeführt
b="$(echo "$a" | sed 's/'\ '/'\|'/g')"
var2=$(curl "http://www.opencaching.de/okapi/services/caches/formatters/gpx?cache_codes=${b}&consumer_key=8YV657YqzqDcVC3QC9wM&ns_ground=true&latest_logs=true&mark_found=true&user_uuid=$UUID" -s)


echo "$var2" >> $output
echo "Die Datei "$output" wird hier im Verzeichnis abgelegt und per Mail versendet."
#sendemail -f "absender@gmail.com" -t "empfänger@gmail.com"  -o tls=yes -s smtp.gmail.com:587 -xu absender@gmail.com -xp password -m "Die gpx für deine Route!" -a $output



