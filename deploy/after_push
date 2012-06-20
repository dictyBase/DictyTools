#!/bin/sh

# $1 = root of the web application folder
deployer=$1
APP_DIR=$2
PROJECT=`basename $APP_DIR`
PERL_VERSION=$3
LOCAL_LIB=$PERL_VERSION\@$PROJECT
SERVICE=$APP_DIR/service
APP_SERVICE=$SERVICE/${PROJECT}runner
RUN_FILE=$APP_SERVICE/run
CONFIG_FOLDER=$4


copy_config() {
	if [ -z "$MOJO_MODE" ]; then
	    MOJO_MODE='production'
	fi

	local config_folder=$1
	local project=$2
	local app_dir=$3

	actual_config=${config_folder}/${project}/${MOJO_MODE}.yaml
	sample_config=${app_dir}/conf/sample.yaml

     
  local running_perl=`which perl`
  if [ -f "$actual_config" ] && [ -f "$sample_config" ]; then
        $running_perl ${app_dir}/deploy/merge_config.pl -c $actual_config \
                             -s $sample_config -m $MOJO_MODE $app_dir
  elif [ -f "$actual_config" ]; then
        $running_perl ${app_dir}/deploy/merge_config.pl -c $actual_config -m $MOJO_MODE $app_dir
  else
        echo cannot find the config files $actual_config
  fi
}

setup_cpanm_perlbrew () {

  local cpanm=$PERLBREW_ROOT/bin/cpanm
  local perlbrew=$PERLBREW_ROOT/bin/perlbrew

  if [ -e $cpanm ]; then
	  echo "------> Upgrading cpanm"
	  $cpanm --self-upgrade
  else
    echo "------> Installing cpanm"
    $perlbrew install-cpanm
  fi

  if ! [ `$perlbrew list | grep $PROJECT` ]; then
	  $perlbrew lib create $LOCAL_LIB
  fi

  echo "-------> using lib $LOCAL_LIB"
  export PERLBREW_ROOT=$PERLBREW_ROOT
  export PERLBREW_HOME=$PERLBREW_HOME
  source ${PERLBREW_ROOT}/etc/bashrc

  # install carton
  cpanm -n Carton
  perlbrew use $LOCAL_LIB
}

# There are few steps for deployment
# 1. setup perlbrew and  cpanm environment
# 2. install dependencies
# 3. copy config file
# 4. put the web application under the control of daemontools(optional)


cd $APP_DIR
if [ -x deploy/$deployer ]; then
  setup_cpanm_perlbrew
	source deploy/${deployer}

	# handle dependencies using two hooks
	before_install_dependencies $APP_DIR
	install_dependencies $APP_DIR
	after_install_dependencies $APP_DIR

	# config file
	copy_config $CONFIG_FOLDER $PROJECT $APP_DIR

	# handle daemontools setup using two hooks
	before_create_daemontools_runfile  $PROJECT $RUN_FILE $LOCAL_LIB $APP_DIR
	create_daemontools_runfile  $PROJECT $RUN_FILE $LOCAL_LIB $APP_DIR
	after_create_daemontools_runfile  $PROJECT $RUN_FILE $LOCAL_LIB $APP_DIR

else
  echo deployer script $deployer do not exist!!!!!
fi
