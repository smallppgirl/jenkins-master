#!/bin/bash

# shellcheck disable=SC1091
source patch/utility.sh

  setup() {
    if [[ ! $ZBR_INSTALLER -eq 1 ]]; then
      set_global_settings
    fi

    # PREREQUISITES: valid values inside ZBR_PROTOCOL, ZBR_HOSTNAME and ZBR_PORT env vars!
    local url="$ZBR_PROTOCOL://$ZBR_HOSTNAME:$ZBR_PORT/jenkins"

    cp .env.original .env
    if [[ "$ZBR_PROTOCOL" == "https" ]]; then
      replace .env "ZBR_JENKINS_PORT=8080" "ZBR_JENKINS_PORT=8443"
    fi

    cp variables.env.original variables.env
    replace variables.env "http://localhost:8080/jenkins" "${url}"
    replace variables.env "INFRA_HOST=localhost:8080" "INFRA_HOST=$ZBR_HOSTNAME:$ZBR_PORT"

    if [[ ! -z $ZBR_SONAR_URL ]]; then
      replace variables.env "SONAR_URL=" "SONAR_URL=${ZBR_SONAR_URL}"
    fi

  }

  shutdown() {
    if [[ -f .disabled ]]; then
      rm -f .disabled
      exit 0 #no need to proceed as nothing was configured
    fi

    docker-compose --env-file .env -f docker-compose.yml down -v
    rm -f variables.env
    rm -f .env
  }


  start() {
    if [[ -f .disabled ]]; then
      exit 0
    fi

    # create infra network only if not exist
    docker network inspect infra >/dev/null 2>&1 || docker network create infra

    if [[ ! -f .env ]]; then
      cp .env.original .env
    fi

    if [[ ! -f variables.env ]]; then
      cp variables.env.original variables.env
    fi

    docker-compose --env-file .env -f docker-compose.yml up -d
  }

  stop() {
    if [[ -f .disabled ]]; then
      exit 0
    fi

    docker-compose --env-file .env -f docker-compose.yml stop
  }

  down() {
    if [[ -f .disabled ]]; then
      exit 0
    fi

    docker-compose --env-file .env -f docker-compose.yml down
  }

  backup() {
    if [[ -f .disabled ]]; then
      exit 0
    fi

    cp .env .env.bak
    cp variables.env variables.env.bak
    docker run --rm --volumes-from jenkins-master -v "$(pwd)"/backup:/var/backup "ubuntu" tar -czvf /var/backup/jenkins-master.tar.gz /var/jenkins_home
  }

  restore() {
    if [[ -f .disabled ]]; then
      exit 0
    fi

    stop
    cp .env.bak .env
    cp variables.env.bak variables.env
    docker run --rm --volumes-from jenkins-master -v "$(pwd)"/backup:/var/backup "ubuntu" bash -c "cd / && tar -xzvf /var/backup/jenkins-master.tar.gz"
    down
  }

  version() {
    if [[ -f .disabled ]]; then
      exit 0
    fi
 
    source .env
    echo "jenkins-master: ${TAG_JENKINS_MASTER}"
  }

  echo_warning() {
    echo "
      WARNING! $1"
  }

  echo_telegram() {
    echo "
      For more help join telegram channel: https://t.me/zebrunner
      "
  }

  set_global_settings() {
    # Setup global settings: protocol, hostname and port
    echo "Zebrunner General Settings"
    local is_confirmed=0
    if [[ -z $ZBR_HOSTNAME ]]; then
      ZBR_HOSTNAME=$HOSTNAME
    fi

    while [[ $is_confirmed -eq 0 ]]; do
      read -r -p "Protocol [$ZBR_PROTOCOL]: " local_protocol
      if [[ ! -z $local_protocol ]]; then
        ZBR_PROTOCOL=$local_protocol
      fi

      read -r -p "Fully qualified domain name (ip) [$ZBR_HOSTNAME]: " local_hostname
      if [[ ! -z $local_hostname ]]; then
        ZBR_HOSTNAME=$local_hostname
      fi

      read -r -p "Port [$ZBR_PORT]: " local_port
      if [[ ! -z $local_port ]]; then
        ZBR_PORT=$local_port
      fi

      confirm "Zebrunner URL: $ZBR_PROTOCOL://$ZBR_HOSTNAME:$ZBR_PORT" "Continue?" "y"
      is_confirmed=$?
    done

    export ZBR_PROTOCOL=$ZBR_PROTOCOL
    export ZBR_HOSTNAME=$ZBR_HOSTNAME
    export ZBR_PORT=$ZBR_PORT

  }

  echo_help() {
    echo "
      Usage: ./zebrunner.sh [option]
      Flags:
          --help | -h    Print help
      Arguments:
          start          Start container
          stop           Stop and keep container
          restart        Restart container
          down           Stop and remove container
          shutdown       Stop and remove container, clear volumes
          backup         Backup container
          restore        Restore container
          version        Version of container"
      echo_telegram
      exit 0
  }

  replace() {
    #TODO: https://github.com/zebrunner/zebrunner/issues/328 organize debug logging for setup/replace
    file=$1
    #echo "file: $file"
    content=$(<"$file") # read the file's content into
    #echo "content: $content"

    old=$2
    #echo "old: $old"

    new=$3
    #echo "new: $new"
    content=${content//"$old"/$new}

    #echo "content: $content"
    printf '%s' "$content" >"$file"    # write new content to disk
  }


BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${BASEDIR}" || exit

case "$1" in
    setup)
          setup
        ;;
    start)
	start
        ;;
    stop)
        stop
        ;;
    restart)
        down
        start
        ;;
    down)
        down
        ;;
    shutdown)
        shutdown
        ;;
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    version)
        version
        ;;
    *)
        echo "Invalid option detected: $1"
        echo_help
        exit 1
        ;;
esac

