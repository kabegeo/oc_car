#!/bin/bash
#Version 0.3.1 / 30.03.2014
#Mailtext im Menü änderbar
#keine Größenbeschränkung mehr
#   je 500 Listings wird eine Mail geschickt.
#
#Version 0.3 / 29.03.2014 
#Das Script kann jetzt selbst Routen erzeugen. Es muss kein gpx File mehr übergeben werden.
#Änderung in der Parameterverwaltung
#	-Als einziger Aufrufparameter bleibt der Dateiname einer 
#		Route (gpx), dieses ist aber optional
#	-Radius, User und Emaildaten werden in einer externen .conf
#		Datei verwaltet. Diese wird selbst erzeugt wenn sie nicht vorhanden ist
#	-In der Eingabemaske kann jetzt ein Start und ein Ziel 
#		der Route angegeben werden. Diese Route wird abgerufen, 
#		wenn keine Route beim Script Start übergeben wurde.
#	-Bei Änderung von Parametern werden diese in der .conf Datei gespeichert.
#
#Bekannter Fehler
#	Bei Anzahl Listings > 500 klappt das (noch) nicht :-(
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

#config Datei prüfen
if [ -f ./oc_car.conf ] ; then
	echo " "
else
	#Schreibe Initialwerte in config File
	{
	echo "ocUser=\"User\""
	echo "Radius=2" 
	echo "Start=\"Stuttgart\"" 
	echo "Ziel=\"München\"" 
	echo "sender=\"absender@gmail.com\"" 
	echo "receiver=\"absender@gmail.com\"" 
	echo "tls=\"tls=yes\"" 
	echo "smtp=\"smtp.gmail.com:587\"" 
	echo "mailuser=\"absender@gmail.com\"" 
	echo "mailpassword=\"password\"" 
	echo "subject=\"oc_car.sh - Die GPX für Deine Route\""
	echo "body=\"Die gpx für deine Route!\"" 
	} >> ./oc_car.conf

	
fi

#externe Variablen einbinden
source oc_car.conf

#Überprüfen der gpx Datei, bzw. ob eine gpx im Aufruf enthalten war.
input=$1
if gpsbabel -i gpx -f $input -o gpx -F - > /dev/null; then
    #echo "GPX Datei ist gültig"
	gpxok="ja"
else
    #echo "GPX Datei ist ungültig! Es wird ein Route über Start / Ziel erstellt."
	gpxok="nein"
fi

#Menü
while [ 1 ]
do
	clear
	echo "Folgende Parameter wurden in der Konfigurationsdatei gefunden:"
	echo "[U]ser:   	" $ocUser
	echo "[R]adius: 	" $Radius
	echo "[S]tart:  	" $Start
	echo "[Z]iel:   	" $Ziel
	echo "[B]etreffzeile:	" $subject
	echo "[M]ail Text:	" $body
	echo "Für den Emailversand werden die in oc_car.conf hinterlegten Parameter genutzt."
	echo ""
	if [ $gpxok == "ja" ]; then
		echo "Es wurde eine gültige gpx-Datei übergeben. Es wird keine neue Route berechnet." 
	else	
		echo "Es wurde keine gültige gpx-Datei übergeben. Es wird eine neue Route berechnet." 
	fi
	echo ""
	echo "Sollen Parameter geändert werden? [N]ein, [E]nde -> [U,R,S,Z,B,M,N,E]"
	read answer
	case $answer in
	u*|U*) echo "Bitte neuen User eingeben:" ; read ocUser ;
		grep -v  ocUser oc_car.conf > tempdatei;
		mv tempdatei oc_car.conf;
		echo "ocUser=$ocUser" >> oc_car.conf;;
	r*|R*) echo "Bitte neuen Radius eingeben:" ; read Radius ;
		grep -v  Radius oc_car.conf > tempdatei;
		mv tempdatei oc_car.conf;
		echo "Radius=$Radius" >> oc_car.conf;;
	s*|S*) echo "Bitte neuen Start eingeben:" ; read Start ;
		grep -v  Start oc_car.conf > tempdatei;
		mv tempdatei oc_car.conf;
		echo "Start=$Start" >> oc_car.conf;;
	z*|Z*) echo "Bitte neues Ziel eingeben:" ; read Ziel ;
		grep -v  Ziel oc_car.conf > tempdatei;
		mv tempdatei oc_car.conf;
		echo "Ziel=$Ziel" >> oc_car.conf;;
	b*|B*) echo "Bitte neuen Emailbetreff eingeben:" ; read subject ;
		grep -v  subject oc_car.conf > tempdatei;
		mv tempdatei oc_car.conf;
		echo "subject=\"$subject\"" >> oc_car.conf;;
	m*|M*) echo "Bitte neuen Email Text eingeben:" ; read body ;
		grep -v  body oc_car.conf > tempdatei;
		mv tempdatei oc_car.conf;
		echo "body=\"$body\"" >> oc_car.conf;;
	n*|N*) echo "" ; break ;;
	e*|E*) clear ; exit ;;
	*) echo das war wohl nichts ;;
	esac
done

#Bildschirm löschen
clear
echo Opencaching.de Caches auf Route

#User ID ermitteln
UUID=$(curl "http://www.opencaching.de/okapi/services/users/by_username?username=$ocUser&fields=uuid&consumer_key=8YV657YqzqDcVC3QC9wM" -s)

#Überprüfen der UserID
if [ ${UUID:0:5} == "{\"err" ]; then
  echo "User nicht gefunden! Bitte Aufrufparameter prüfen -> z.B. ./oc_car.sh route.gpx 1.5 ka_be" 
  exit
fi
echo "User wurde gefunden."

# Abruf der Route
if [ $gpxok == "nein" ]; then

# Die Geokoordinaten werden mit Hilfe von mapquest abgerufen
Start_1=$(curl "http://www.mapquestapi.com/geocoding/v1/address?location=$Start&outFormat=xml&key=Fmjtd%7Cluur2l0tn5%2Cbw%3Do5-9a7g0r" -s)
Ziel_1=$(curl "http://www.mapquestapi.com/geocoding/v1/address?location=$Ziel&outFormat=xml&key=Fmjtd%7Cluur2l0tn5%2Cbw%3Do5-9a7g0r" -s)

# Zuerst Suche ich in der Variable eine Zeile mit <lat>, dann ersetze ich <lat> und </lat> durch "", dann lese ich diese Zeile bis zur 1. " "
latS=$(awk '{print $1}' <<<$(echo "$Start_1" | grep '<lat>' | sed -e "s/<lat>//" -e "s/<\/lat>//"))
lngS=$(awk '{print $1}' <<<$(echo "$Start_1" | grep '<lng>' | sed -e "s/<lng>//" -e "s/<\/lng>//"))
echo lng:$lngS
echo lat:$latS
latZ=$(awk '{print $1}' <<<$(echo "$Ziel_1" | grep '<lat>' | sed -e "s/<lat>//" -e "s/<\/lat>//"))
lngZ=$(awk '{print $1}' <<<$(echo "$Ziel_1" | grep '<lng>' | sed -e "s/<lng>//" -e "s/<\/lng>//"))
echo lng:$lngZ
echo lat:$latZ

# Die Route wird über project-osrm abgerufen und in die Datei route.gpx gespeichert
curl "http://router.project-osrm.org/viaroute?loc=$latS,$lngS&loc=$latZ,$lngZ&output=gpx&alt=false" -s > ./route.gpx

#Überprüfen der gpx Datei
	if gpsbabel -i gpx -f route.gpx -o gpx -F - > /dev/null; then
		echo "GPX Datei ist gültig"
	else
		echo "GPX Datei ist ungültig! Der download der Route ist fehlgeschlagen"
		exit
	fi

fi

#Überprüfen des Radius
if [ $Radius -gt 0 ]; then
    if [ $Radius -lt 11 ]; then
		echo "Radius ist ok"
	else
		echo "Radius muss zwischen 0.1 und 10 liegen! Bitte Parameter prüfen"
		exit
	fi
else
    echo "Radius muss zwischen 0.1 und 10 liegen! Bitte Parameter prüfen"
	exit
fi

# rechts 2 Zeichen abschneiden
UUID=${UUID%??}
# links 9 Zeichen abschneiden
UUID=${UUID#?????????}
echo
#echo "Deine UserID ist "$UUID
#echo


#error und distance sind Parameter für die Bearbeitung der Route und zum Festlegen der Koordinaten für die jeweilige
#Umkreissuche.
#circle ist die maximale breite des Korridors
#Bei einem Verhältniss error/circle ~1/4 und distance/circle ~ 5/4 ergibt dass eine mindest Abdeckung von ca. 2/3 von circle
error="0"$( echo "scale=2; $Radius / 4" | bc )"k"      # Douglas-Peucker tolerance
distance="0"$(echo "scale=2; $Radius / 4 * 5" | bc)"k"   # interpolation distance
circle=$Radius   # Suchradius in km

echo "Der max. Abstand zur festgelegten Route beträgt "$(echo "scale=3; $circle / 2" | bc)"km."
echo "Alle "$distance"m wird eine neue OC.de Abfrage durchgeführt."
echo "Zur Glättung der Route wird der Wert "$error"m genutzt."
echo
echo "Das kann jetzt ein paar Sekunden dauern..."

#gpsbabel zum Glätten und berechnen der Koordinaten für die jeweilige Umkreissuche
if [ $gpxok == "ja" ]; then
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
else
searchargs=$(
cat route.gpx |
gpsbabel -i gpx -f - \
    -x simplify,crosstrack,error=$error \
         -o gpx -F - |
gpsbabel -i gpx -f - \
    -x interpolate,distance=$distance \
         -o csv -F - |
tr ',' ' ' |
awk '{printf("%.3f,%.3f|",$1,$2)}'

)
fi


#echo $searchargs
echo "Punkte auf der Route wurden berechnet!"
echo
echo "An diesen Punkten wird mit einem Radius von "$circle"km nach OC Dosen gesucht:"
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
echo " Prozent      - Anzahl Listings"
echo
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
echo -en "\r$prozent % - $anzahl"
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
echo -en "\r$prozent % - $anzahl"
fi
done
echo
#Hier werden Duplikate aus dem String gefiltert
a="$(echo "$alle" | xargs -n1 | sort -u | xargs)"
echo -n "Gefundene Listings ohne Duplikate: " 
zahl=$(echo $a | wc -w)
echo $zahl

#Anzahl Abrufe zu je 500 bestimmen
loop=$(($zahl / 500))

for (( c=0; c<=$loop; c++ ))
do
spalte=$[(c * 500) + 1]
f=$(echo $a | cut -d" " -f$spalte-$(($spalte+499))) 

#echo $f

#Die auszugebende Geocaching gpx Datei bestimmen -> Format (YYMMDD-HHMMSS)PQ.gpx
output=($(date "+%y%m%d-%H%M%S")PQ.gpx)

#Jetzt werden die | zwischen die OCcodes eingefügt und der Okapi Aufruf durchgeführt
g="$(echo "$f" | sed 's/'\ '/'\|'/g')"
var2=$(curl "http://www.opencaching.de/okapi/services/caches/formatters/gpx?cache_codes=${g}&consumer_key=8YV657YqzqDcVC3QC9wM&ns_ground=true&latest_logs=true&mark_found=true&user_uuid=$UUID" -s)
echo "$var2" >> $output
echo "Die Datei "$output" wird hier im Verzeichnis abgelegt und per Mail versendet."
sendemail -f $sender -t $receiver -o $tls -s $smtp -xu $mailuser -xp $mailpassword -u $subject -m $body -a $output
done
exit






