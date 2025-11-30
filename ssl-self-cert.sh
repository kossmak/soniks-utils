#!/usr/bin/env bash
# set -x         # отладка: полный лог исполняемых команд
# set -o xtrace  # отладка: полный лог исполняемых команд


: ${BASENAME}                   # пример: luk
: ${DOMAIN:="${BASENAME}.loc"}  # luk.loc
: ${WILDCARD:="*.${DOMAIN}"}    # *.luk.loc
: ${CA_NAME:="${BASENAME}CA"}  # luk-CA

# ~/luk-CA/luk.loc/
mkdir -p ~/${CA_NAME}/$DOMAIN
cd ~/${CA_NAME}/$DOMAIN

# --- 1. Корневой CA ---
openssl genrsa -out ${CA_NAME}.key 4096
openssl req -x509 -new -nodes -key ${CA_NAME}.key \
    -sha256 -days 3650 -out ${CA_NAME}.pem \
    -subj "/C=RU/ST=Dev/L=Dev/O=${CA_NAME}LocalCA/CN=${CA_NAME} Local Root CA"

# --- 2. Ключ домена ---
openssl genrsa -out $DOMAIN.key 2048

# --- 3. SAN-файл ---
cat > san.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = $WILDCARD
EOF

# --- 4. CSR ---
openssl req -new -key $DOMAIN.key -out $DOMAIN.csr \
    -subj "/C=RU/ST=Dev/L=Dev/O=${CA_NAME}LocalCA/CN=$DOMAIN"

# --- 5. Подписываем сертификат ---
openssl x509 -req -in $DOMAIN.csr \
  -CA ${CA_NAME}.pem -CAkey ${CA_NAME}.key -CAcreateserial \
  -out $DOMAIN.pem -days 825 -sha256 -extfile san.cnf

echo ""
echo "Готово!"
echo " Файлы:"
ls -l
echo ""
echo "Установите ${host_ca_crt} в Windows → Trusted Root Certification Authorities"
