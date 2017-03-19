#!/bin/bash
#see https://docs.docker.com/engine/security/https/

EXPIRATIONDAYS=700
CASUBJSTRING="/C=/ST=/L=/O=MyCompany/OU=IT/CN=DockerProd/emailAddress=test@example.de"

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -m|--mode)
    MODE="$2"
    shift 
    ;;
    -h|--hostname)
    SERVERNAME="$2"
    shift 
    ;;
    -hip|--hostip)
    SERVERIP="$2"
    shift 
    ;;    
    -pw|--password)
    PASSWORD="$2"
    shift 
    ;;
    -t|--targetdir)
    TARGETDIR="$2"
    shift 
    ;;    
    -e|--expirationdays)
    EXPIRATIONDAYS="$2"
    shift 
    ;;    
    --ca-subj)
    CASUBJSTRING="$2"
    shift 
    ;; 
    *)
            # unknown option
    ;;
esac
shift 
done

echo "Mode $MODE"
echo "Host $SERVERNAME"
echo "Host IP $SERVERIP"
echo "Targetdir $TARGETDIR"
echo "Expiration $EXPIRATIONDAYS"

programname=$0

function usage {
    echo "usage: $programname -m ca -h example.de [-hip 1.2.3.4] -pw my-secret -t /target/dir [-e 365]"
    echo "  -m|--mode                 'ca' to create CA, 'server' to create server cert, 'client' to create client cert"
    echo "  -h|--hostname|-n|--name   DNS hostname for the server or name of client"
    echo "  -hip|--hostip             host's IP - default: none"
    echo "  -pw|--password            Password for CA Key generation"
    echo "  -t|--targetdir            Targetdir for certfiles and keys"
    echo "  -e|--expirationdays       certificate expiration in day - default: 700 days"    
    echo "  --ca-subj                 subj string for ca cert"
    exit 1
}

function createCA {
    openssl genrsa -aes256 -passout pass:$PASSWORD -out $TARGETDIR/ca-key.pem 4096
    openssl req -passin pass:$PASSWORD -new -x509 -days $EXPIRATIONDAYS -key $TARGETDIR/ca-key.pem -sha256 -out $TARGETDIR/ca.pem -subj $CASUBJSTRING
    
    chmod 0400 $TARGETDIR/ca-key.pem
    chmod 0444 $TARGETDIR/ca.pem
}

function createServerCert {
    openssl genrsa -out $TARGETDIR/server-key.pem 4096
    openssl req -subj "/CN=$SERVERNAME" -new -key $TARGETDIR/server-key.pem -out $TARGETDIR/server.csr
    echo "subjectAltName = DNS:$SERVERNAME,IP:$SERVERIP" > $TARGETDIR/extfile.cnf
    openssl x509 -passin pass:$PASSWORD -req -days $EXPIRATIONDAYS -in $TARGETDIR/server.csr -CA $TARGETDIR/ca.pem -CAkey $TARGETDIR/ca-key.pem -CAcreateserial -out $TARGETDIR/server-cert.pem -extfile $TARGETDIR/extfile.cnf

    rm $TARGETDIR/server.csr $TARGETDIR/extfile.cnf
    chmod 0400 $TARGETDIR/server-key.pem
    chmod 0444 $TARGETDIR/server-cert.pem
}

function createClientCert {
    openssl genrsa -out $TARGETDIR/client-key.pem 4096
    openssl req -subj '/CN=client' -new -key $TARGETDIR/client-key.pem -out $TARGETDIR/client.csr
    echo "extendedKeyUsage = clientAuth" > $TARGETDIR/extfile.cnf
    openssl x509 -passin pass:$PASSWORD -req -days 365 -sha256 -in $TARGETDIR/client.csr -CA $TARGETDIR/ca.pem -CAkey $TARGETDIR/ca-key.pem -CAcreateserial -out $TARGETDIR/client-cert.pem -extfile $TARGETDIR/extfile.cnf

    rm $TARGETDIR/client.csr $TARGETDIR/extfile.cnf
    chmod 0400 $TARGETDIR/client-key.pem
    chmod 0444 $TARGETDIR/client-cert.pem
}


if [[ -z $MODE || -z $SERVERNAME || -z $PASSWORD || -z $TARGETDIR ]]; then
    usage   
fi

mkdir -p $TARGETDIR

if [[ $MODE = "ca" ]]; then 
    createCA
elif [[ $MODE = "server" ]]; then
    createServerCert
elif [[ $MODE = "client" ]]; then
    createClientCert
else
    usage
fi
