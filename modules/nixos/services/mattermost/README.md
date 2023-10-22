# Mattermost README

You need to crate a KV in Vault for Mattermost secrets. Use the following to get started.


```
vault kv put secret/campground/mattermost \
  DOMAIN=mm.example.com \
  TZ=UTC \
  RESTART_POLICY=unless-stopped \
  POSTGRES_IMAGE_TAG=13-alpine \
  POSTGRES_DATA_PATH=./volumes/db/var/lib/postgresql/data \
  POSTGRES_USER=mmuser \
  POSTGRES_PASSWORD=mmuser_password \
  POSTGRES_DB=mattermost \
  NGINX_IMAGE_TAG=alpine \
  NGINX_CONFIG_PATH=./nginx/conf.d \
  NGINX_DHPARAMS_FILE=./nginx/dhparams4096.pem \
  CERT_PATH=./volumes/web/cert/cert.pem \
  KEY_PATH=./volumes/web/cert/key-no-password.pem \
  HTTPS_PORT=443 \
  HTTP_PORT=80 \
  CALLS_PORT=8443 \
  MATTERMOST_CONFIG_PATH=./volumes/app/mattermost/config \
  MATTERMOST_DATA_PATH=./volumes/app/mattermost/data \
  MATTERMOST_LOGS_PATH=./volumes/app/mattermost/logs \
  MATTERMOST_PLUGINS_PATH=./volumes/app/mattermost/plugins \
  MATTERMOST_CLIENT_PLUGINS_PATH=./volumes/app/mattermost/client/plugins \
  MATTERMOST_BLEVE_INDEXES_PATH=./volumes/app/mattermost/bleve-indexes \
  MM_BLEVESETTINGS_INDEXDIR=/mattermost/bleve-indexes \
  MATTERMOST_IMAGE=mattermost-enterprise-edition \
  MATTERMOST_IMAGE_TAG=7.8 \
  MATTERMOST_CONTAINER_READONLY=false \
  APP_PORT=8065 \
  MM_SQLSETTINGS_DRIVERNAME=postgres

```
