#!/bin/sh

# install perl modules for reverse proxy deployment
# of web application.


# gets the project folder as the param
install_dependencies() {
	 cd $1
   carton install
}

after_install_dependencies() {
   echo "------> Installing plack and dependencies for fcgi deployment"
   cd $1
   carton install Plack Starman
}

before_install_dependencies() {
  return
}

create_daemontools_runfile(){

  local PROJECT=$1
  local RUN_FILE=$2
  local LOCAL_LIB=$3
  local APP_DIR=$4

  echo -e "#!/bin/sh\nexec 2>1&\n" > $RUN_FILE
  echo "export HOME=$HOME" >> $RUN_FILE
  echo -e "cd $APP_DIR\n" >> $RUN_FILE
  echo "source ${PERLBREW_ROOT}/etc/bashrc" >> $RUN_FILE
  echo "perlbrew use $LOCAL_LIB" >> $RUN_FILE
  echo  "export MOJO_MODE=production" >> $RUN_FILE
  echo  "exec setuidgid $USER carton exec -Ilib  -- plackup -p 9800 -E production -r -R template -s Starman --workers 5 script/${PROJECT}" >> $RUN_FILE
}

before_create_daemontools_runfile() {
   return
}

after_create_daemontools_runfile() {

  local PROJECT=$1
  local RUN_FILE=$2
  local LOCAL_LIB=$3
  local APP_DIR=$4
  local SERVICE=${APP_DIR}/service
  local APP_SERVICE=${SERVICE}/${PROJECT}runner
  local RUN_FILE=${APP_SERVICE}/run

	! [ -d $APP_SERVICE ] && mkdir -p $APP_SERVICE

	if  [ ! -e $RUN_FILE ];then 
		cd $APP_DIR
		chmod 1755 $APP_SERVICE
		chmod 755 $RUN_FILE
		ln -s $APP_SERVICE /service/${PROJECT}
	fi
}


