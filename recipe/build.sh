#!/bin/bash
set -eux

_builddir="_build"
rm -rf ${_builddir}
mkdir -pv ${_builddir}
pushd ${_builddir}

# add globus header directory to include path
CFLAGS="$(pkg-config --cflags-only-I globus-common) ${CFLAGS} "
CXXFLAGS="$(pkg-config --cflags-only-I globus-common) ${CXXFLAGS}"

# link libdl
if [ "$(uname)" == "Linux" ]; then
	export LDFLAGS="-ldl -lrt ${LDFLAGS}"
fi

# configure
cmake $SRC_DIR \
	-D_VERBOSE:BOOL=TRUE \
	-DBUILD_SHARED_LIBS:BOOL=TRUE \
	-DBUILD_TESTING:BOOL=FALSE \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
	-DCMAKE_INSTALL_LIBDIR:PATH="lib" \
	-DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
	-DDLOPEN_SECURITY_LIBS:BOOL=FALSE \
	-DDLOPEN_GSI_LIBS:BOOL=FALSE \
	-DENABLE_JAVA_TESTS:BOOL=FALSE \
	-DHAVE_BOINC:BOOL=FALSE \
	-DPROPER:BOOL=TRUE \
	-DPYTHON_EXECUTABLE:PATH=FALSE \
	-DPYTHON3_EXECUTABLE:PATH=FALSE \
	-DUW_BUILD:BOOL=FALSE \
	-DWANT_FULL_DEPLOYMENT:BOOL=FALSE \
	-DWANT_MAN_PAGES:BOOL=TRUE \
	-DWITH_BLAHP:BOOL=FALSE \
	-DWITH_BOINC:BOOL=FALSE \
	-DWITH_CREAM:BOOL=FALSE \
	-DWITH_GANGLIA:BOOL=TRUE \
	-DWITH_GLOBUS:BOOL=TRUE \
	-DWITH_KRB5:BOOL=TRUE \
	-DWITH_MUNGE:BOOL=TRUE \
	-DWITH_PYTHON_BINDINGS:BOOL=FALSE \
	-DWITH_SCITOKENS:BOOL=FALSE \
	-DWITH_VOMS:BOOL=TRUE

# build
cmake --build . --parallel ${CPU_COUNT}

# install
cmake --build . --parallel ${CPU_COUNT} --target install

# -- create the condor_config file

cp -v ${SRC_DIR}/src/condor_examples/condor_config.generic condor_config.patched
patch condor_config.patched ${RECIPE_DIR}/condor_config.generic.conda.patch
install -m=0644 -T condor_config.patched ${PREFIX}/etc/condor/condor_config

# -- create activate/deactivate scripts

# activate.sh
ACTIVATE_SH="${PREFIX}/etc/conda/activate.d/activate_condor.sh"
mkdir -p $(dirname ${ACTIVATE_SH})
cat > ${ACTIVATE_SH} << EOF
#!/bin/bash
export CONDA_BACKUP_CONDOR_CONFIG="\${CONDOR_CONFIG:-empty}"
export CONDOR_CONFIG="/opt/anaconda1anaconda2anaconda3/etc/condor/condor_config"
EOF

# deactivate.sh
DEACTIVATE_SH="${PREFIX}/etc/conda/deactivate.d/deactivate_condor.sh"
mkdir -p $(dirname ${DEACTIVATE_SH})
cat > ${DEACTIVATE_SH} << EOF
#!/bin/bash
if [ "\${CONDA_BACKUP_CONDOR_CONFIG}" = "empty" ]; then
	unset CONDOR_CONFIG
else
	export CONDOR_CONFIG="\${CONDA_BACKUP_CONDOR_CONFIG}"
fi
unset CONDA_BACKUP_CONDOR_CONFIG
EOF
