#!/usr/bin/env bash


# get absolute path to directory where script is located
DIR_ROOT="$(dirname $0)"
cd "${DIR_ROOT}"
DIR_ROOT="$(pwd)"

# get username & email
ARGS=("$@")
for idx in $(seq 0 `expr $# - 1`); do
	ARG="${ARGS[${idx}]}"

	if test "${ARG}" == "-u"; then
		DEBFULLNAME="${ARGS[${idx}+1]}"
	elif test "${ARG}" == "-e"; then
		DEBEMAIL="${ARGS[${idx}+1]}"
	fi
done

FILE_INFO="${DIR_ROOT}/INFO"

if test ! -f "${FILE_INFO}"; then
	echo -e "\nERROR: Could not find info file: ${FILE_INFO}"
	exit 1
fi

. "${FILE_INFO}"

# make sure required variables are available
if test -z "${VER}"; then
	echo -e "\nERROR: could not determine version info"
	exit 1
fi

BASENAME="wxsvg-${VER}"
FILENAME="${BASENAME}.tar.bz2"
FILE="${DIR_ROOT}/${FILENAME}"
SOURCE="https://downloads.sourceforge.net/wxsvg/wxsvg/${VER}/${BASENAME}.tar.bz2"

if test ! -f "${FILE}"; then
	wget "${SOURCE}"
else
	echo -e "\nNot re-downloading source: ${FILE}"
fi

DHMAKE_DONE=false

FILE_SETUP="${DIR_ROOT}/SETUP"
if test -f "${FILE_SETUP}"; then
	. "${FILE_SETUP}"
fi

if test -d "${DIR_ROOT}/libwxsvg/debian"; then
	echo -e "\nWARNING: Not overwriting debian directory. Please delete if you would like to do so: ${DIR_ROOT}/libwxsvg/debian"
else
	echo -e "\nRunning dh_make ..."

	if test ! -d "${DIR_ROOT}/libwxsvg"; then
		mkdir -p "${DIR_ROOT}/libwxsvg"
	elif test -d "${DIR_ROOT}/libwxsvg/debian"; then
		echo -e "\nWARNING: overwriting old debian directory: ${DIR_ROOT}/libwxsvg/debian"
		rm -r "${DIR_ROOT}/libwxsvg/debian"
	fi

	cd "${DIR_ROOT}/libwxsvg"

	# maintainer & email values are automatically set by DEBFULLNAME & DEBEMAIL variables
	export DEBFULLNAME DEBEMAIL

	dh_make -y -l -c "custom" --copyrightfile "${DIR_ROOT}/LICENSE.txt" -p "libwxsvg_${VER}" -f "${FILE}"

	FILE_CTRL="${DIR_ROOT}/libwxsvg/debian/control"
	echo -e "\nEditing ${FILE_CTRL} ..."

	DESCR_LONG=" <long\n description>"
	sed -i \
		-e 's|libwxsvgBROKEN|libwxsvg|' \
		-e 's|\(Build-Depends:.*$\)|\1, libwxgtk3.0-dev \| libwxgtk3.0-gtk3-dev|g' \
		-e 's|\(Depends: ${shlibs:Depends}, ${misc:Depends}\)|\1, libwxgtk3.0-0v5 \| libwxgtk3.0-gtk3-0v5|g' \
		-e 's|Homepage:.*$|Homepage: http://wxsvg.sourceforge.net/|g' \
		-e 's|Description:.*$|Description: C++ library to create, manipulate and render Scalable Vector Graphics|g' \
		-e "s|^.*<insert long description.*$|${DESCR_LONG}|g" \
		-e '/#Vcs-.*$/d' \
		"${FILE_CTRL}"

	echo -e "\nEditing changelog ..."
	FILE_CHANGES="${DIR_ROOT}/libwxsvg/debian/changelog"
	#sed -i -e 's|^libwxsvg\( (.*$\)|wxsvg\1|g' "${FILE_CHANGES}"

	echo -e "\nEditing ${FILE_RULES} ..."
	FILE_RULES="${DIR_ROOT}/libwxsvg/debian/rules"
	echo -e "#!/usr/bin/make -f

export DEB_BUILD_MAINT_OPTIONS=hardening=+all
export DEB_LDFLAGS_MAINT_APPEND = -Wl,--as-needed

%:
	dh \$@ --with=autoreconf

override_dh_auto_configure:
	dh_auto_configure -- --enable-static=no

override_dh_missing:
	dh_missing --fail-missing

override_dh_auto_install:
	dh_auto_install
	find . -name \\*.la -delete" > "${FILE_RULES}"

	echo -e "\nRemoving example files ..."

	find debian/ -type f -name "*.[eE][xX]" -print -delete

	echo -e "\nAdding meta data ..."

	DIR_UPSTREAM="${DIR_ROOT}/libwxsvg/debian/upstream"
	if test ! -d "${DIR_UPSTREAM}"; then
		mkdir -p "${DIR_UPSTREAM}"
	fi

	echo -e "---
Name: wxsvg
Repository: https://git.code.sf.net/p/wxsvg/git
Repository-Browse: https://sourceforge.net/p/wxsvg/git/ci/master/tree/" > "${DIR_UPSTREAM}/metadata"

	echo -e "\nAdding patches ..."
	DIR_PATCHES="${DIR_ROOT}/libwxsvg/debian/patches"
	if test -d "${DIR_ROOT}/patches"; then
		for P in $(find "${DIR_ROOT}/patches" -type f -name "*.patch"); do
			if test ! -d "${DIR_PATCHES}"; then
				mkdir -p "${DIR_PATCHES}"
			fi

			cp "${P}" "${DIR_PATCHES}"
			echo "$(basename ${P})" >> "${DIR_PATCHES}/series"
		done
	fi

	echo -e "\nBuilding package ..."

	dpkg-buildpackage -rfakeroot

	# TODO: edit debian/changelog & debian/README.*

	echo -e "\nDone!"
fi

cd "${DIR_ROOT}"

