#!/usr/bin/env bash
set -x
BNANAME=$1
ORGCNT=$2

WS=$PWD
CRYPTO_CONF=$WS/crypto-config
OUT=$WS/tmp/composer
BASE_CONNECT_TEMP_FILE=$OUT/fund-clearing.json
ORG_CONNECT_TEMP_FILE=$WS/org-connection-temp.json

function init() {
    if [ ! -d $CRYPTO_CONF ]; then
        echo "$CRYPTO_CONF not exists"
        exit 1
    fi;

    for orgnum in $(seq 1 $ORGCNT)
     do
        echo $orgnum
        mkdir -p $OUT/org$orgnum
    done
}

function createBaseConnectFile() {
    cp $WS/connection-temp.json $BASE_CONNECT_TEMP_FILE
    awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' $CRYPTO_CONF/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt > $OUT/ca-orderer.txt
    sed -i "/INSERT_ORDERER_CA_CERT/r $OUT/ca-orderer.txt" $BASE_CONNECT_TEMP_FILE
    sed -i ':a;N;$!ba;s/INSERT_ORDERER_CA_CERT"\n//g' $BASE_CONNECT_TEMP_FILE

    for orgnum in $(seq 1 $ORGCNT)
     do
        awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' $CRYPTO_CONF/peerOrganizations/org$orgnum.example.com/peers/peer0.org$orgnum.example.com/tls/ca.crt > $OUT/org$orgnum.txt
        sed -i "/INSERT_ORG${orgnum}_CA_CERT/r  $OUT/org${orgnum}.txt" $BASE_CONNECT_TEMP_FILE
        sed -i ':a;N;$!ba;s/'\"INSERT_ORG${orgnum}_CA_CERT\"'\n/"/g' $BASE_CONNECT_TEMP_FILE
    done
    sed -i 's/END CERTIFICATE-----\\n/END CERTIFICATE-----\\n"/g' $BASE_CONNECT_TEMP_FILE
}

function createOrgConnectionFile() {
    for orgnum in $(seq 1 $ORGCNT); do
        cp $ORG_CONNECT_TEMP_FILE $ORG_CONNECT_TEMP_FILE.tmp
        sed -i "s/ORGNAME/Org$orgnum/g" $ORG_CONNECT_TEMP_FILE.tmp
        cp $BASE_CONNECT_TEMP_FILE $OUT/org$orgnum/fund-clearing-org$orgnum.json
        sed -i "/version/r $ORG_CONNECT_TEMP_FILE.tmp" $OUT/org$orgnum/fund-clearing-org$orgnum.json
        rm -f $ORG_CONNECT_TEMP_FILE.tmp
    done
}

function createPeerAdminCard() {
    for orgnum in $(seq 1 $ORGCNT); do
        MSP=$CRYPTO_CONF/peerOrganizations/org$orgnum.example.com/users/Admin@org$orgnum.example.com/msp
        cp -p $MSP/signcerts/A*.pem $OUT/org$orgnum
        cp -p $MSP/keystore/*_sk $OUT/org$orgnum
        composer card create -p $OUT/org$orgnum/fund-clearing-org$orgnum.json -u PeerAdmin -c $OUT/org$orgnum/Admin@org$orgnum.example.com-cert.pem -k $OUT/org$orgnum/*_sk -r PeerAdmin -r ChannelAdmin -f $OUT/org$orgnum/PeerAdmin@fund-clearing-org$orgnum.card
    done
}

function importPeerAdminCard() {
    for orgnum in $(seq 1 $ORGCNT); do
        composer card import -f $OUT/org$orgnum/PeerAdmin@fund-clearing-org$orgnum.card --card PeerAdmin@fund-clearing-org$orgnum
    done
}

function archiveNetwork() {
    composer archive create fund-clearing-network -t dir -n $WS/../../fund-clearing-network -a $OUT/fund-clearing.bna
}

function deployNetwork() {
    for orgnum in $(seq 1 $ORGCNT); do
        composer network install --card PeerAdmin@fund-clearing-org$orgnum --archiveFile $OUT/fund-clearing.bna
        composer identity request -c  PeerAdmin@fund-clearing-org$orgnum -u admin -s adminpw -d $OUT/org$orgnum/admin
    done
    composer network start -c PeerAdmin@fund-clearing-org1 -n fund-clearing-network -V 0.2.6 -o endorsementPolicyFile=$WS/endorsement-policy.json -A NetOrg1Admin -C $OUT/org1/admin/admin-pub.pem -A NetOrg2Admin -C $OUT/org2/admin/admin-pub.pem -A NetOrg3Admin -C $OUT/org3/admin/admin-pub.pem
}

function generateAndImportNeworkCard() {
    for orgnum in $(seq 1 $ORGCNT); do
        composer card create -p $OUT/org$orgnum/fund-clearing-org$orgnum.json -u NetOrg${orgnum}Admin -n fund-clearing-network -c $OUT/org$orgnum/admin/admin-pub.pem -k $OUT/org$orgnum/admin/admin-priv.pem -f $OUT/org${orgnum}/NetOrg${orgnum}Admin@fund-clearing-network.card
        composer card import -f $OUT/org${orgnum}/NetOrg${orgnum}Admin@fund-clearing-network.card -c NetOrg${orgnum}Admin@fund-clearing-network
        composer network ping -c NetOrg${orgnum}Admin@fund-clearing-network
    done
}

init
createBaseConnectFile
createOrgConnectionFile
createPeerAdminCard
importPeerAdminCard
archiveNetwork
deployNetwork
generateAndImportNeworkCard
