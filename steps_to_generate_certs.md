made serial using $ echo '1001' > serial
made xpextensions and added following lines

[ xpclient_ext ]
extendedKeyUsage = 1.3.6.1.5.5.7.3.2

[ xpserver_ext ]
extendedKeyUsage = 1.3.6.1.5.5.7.3.1

use --config openssl.conf on necessary command

Commands on each line : 



openssl req -new -x509 -keyout wpa2_ca.key -out wpa2_ca.pem -nodes
openssl req -new -nodes -keyout wpa2_server.key -out wpa2_server.csr -days 1000
openssl ca -batch -keyfile wpa2_ca.key -cert wpa2_ca.pem -in wpa2_server.csr -out wpa2_server.crt -extensions xpserver_ext -extfile xpextensions
openssl genrsa -nodes -out wpa2_client.key 4096
openssl req -new -key wpa2_client.key -out wpa2_client.csr

**Changed `certindex.txt.attr` Unique identity to yes to directtly take the same entity. Else a list or database have to be provided.**
openssl ca -batch -keyfile wpa2_ca.key -cert wpa2_ca.pem -in wpa2_client.csr -out wpa2_client.crt -extensions xpclient_ext -extfile xpextensions

**Maybe used for sha512 CERTIFICATES**
openssl x509 -sha512 -req -days 36500 -CA wpa2_ca.pem -CAkey wpa2_ca.key -CAcreateserial -CAserial serial -in wpa2_client_4096_sha512.csr -out wpa2_client_4096_sha512.crt


// Steps to generate 
1. openssl genrsa -des3 -out wpa2_client.key 2048
2. openssl req -new -key wpa2_client.key -out wpa2_client.csr -config openssl.cnf
3. openssl ca -batch -keyfile wpa2_ca.key -cert wpa2_ca.pem -in wpa2_client.csr -out wpa2_client.crt -extensions xpclient_ext -extfile xpextensions -config openssl.cnf
