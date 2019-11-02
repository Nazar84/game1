WHOAMI          ?=  ${shell whoami}

export APP_ROOT ?=  ${shell pwd -P}
export CONF_DIR ?=  ${APP_ROOT}/etc
export APP      ?=  ${APP_ROOT}/app/maitre_d/run.pl

export PATH     :=  ${APP_ROOT}/local/bin:${PATH}

LOCAL_LIBS      :=  ${APP_ROOT}/lib
LOCAL_LIBS      :=  ${LOCAL_LIBS}:${APP_ROOT}/local/lib/perl5
export PERL5LIB :=  ${LOCAL_LIBS}:${PERL5LIB}


# Run this target as: eval `make setenv`
setenv:
	export PATH=${PATH}
	export PERL5LIB=${LOCAL_LIBS}
	export PERL5DB="use DB::Hooks qw'::Terminal NonStop'"
	export PERLDB_OPTS="white_box"
	export MOJO_INACTIVITY_TIMEOUT=0

# Hint: How to debug DBIC
# DBIC_TRACE_PROFILE=console DBIC_TRACE=1 <cmd>

# locate pg_config
# POSTGRES_HOME=/usr/pgsql-10 BIN



include ${CONF_DIR}/db_env.conf


dbshell: export PGPASSWORD =  ${DB_PASS}
dbshell:
	psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} ${DB_NAME} ||:
