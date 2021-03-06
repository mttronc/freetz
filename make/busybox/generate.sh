#!/bin/bash
# Generates a Config.in(.busybox) of Busybox for Freetz
BBDIR="$(dirname $(readlink -f $0))"
BBVER="$(sed -n 's/$(call PKG_INIT_BIN, \(.*\))/\1/p' $BBDIR/busybox.mk)"
BBOUT="$BBDIR/Config.in.busybox"
BBDEP="$BBDIR/busybox.rebuild-subopts.mk.in"

# supports int/bool/string/choice values
default() {
	sed -r -i '/(^config FREETZ_BUSYBOX_'"$1"'$|^[ \t]*prompt "'"$1"'")/,+5 {
		s,(\tdefault )("?)[^"]*\2,\1\2'"$2"'\2,
	}' "$BBOUT"
}

depends_on() {
	sed -r -i '/^config FREETZ_BUSYBOX_'"$1"'/,+5 {
		/^[ \t]+depends on[ \t]/ {
			# "depends on" already exists => append && at the end and move the line to the hold buffer
			s,$, \&\&,
			h;d
		}
		/^[ \t]+help$/ {
			# eXchange pattern<-->hold buffers
			x
			# empty buffer => no "depends on" seen => add it
			s,^$,\tdepends on,
			# append new/additional condition at the end
			s,$, '"$2"',
			# get the help line back from the hold buffer
			G
		}
	}' "$BBOUT"
}

select_() {
	sed -r -i '/^config FREETZ_BUSYBOX_'"$1"'/,/^[ \t]+help$/ {
		/^[ \t]+help$/ i\
	select '"$2"'
	}' "$BBOUT"
}

echo -n "unpacking ..."
rm -rf "$BBDIR/busybox-$BBVER"
tar xf "$BBDIR/../../dl/busybox-$BBVER.tar.bz2" -C "$BBDIR"

echo -n " patching ..."
cd "$BBDIR/busybox-$BBVER/"
for p in $BBDIR/patches/*.patch; do
	patch -p0 < $p >/dev/null
done

echo -n " building ..."
FREETZ_GENERATE_CONFIG_IN_ONLY=y ./scripts/gen_build_files.sh "$BBDIR/busybox-$BBVER/" "$BBDIR/busybox-$BBVER/" >/dev/null

echo -n " parsing ..."
echo -e "\n### Do not edit this file! Run generate.sh to create it. ###\n\n" > "$BBOUT"
$BBDIR/../../tools/parse-config Config.in >> "$BBOUT" 2>/dev/null
rm -rf "$BBDIR/busybox-$BBVER"

echo -n " searching ..."
nonfeature_symbols=""
feature_symbols=""
for symbol in $(sed -n 's/^config //p' "$BBOUT"); do
	if [ "${symbol:0:8}" != "FEATURE_" ]; then
		nonfeature_symbols="${nonfeature_symbols}${nonfeature_symbols:+|}${symbol}"
	else
		feature_symbols="${feature_symbols}${feature_symbols:+|}${symbol}"
	fi
done

echo -n " replacing ..."
sed -i -r \
	-e "s,([ (!])(${feature_symbols})($|[ )]),\1FREETZ_BUSYBOX_\2\3,g" \
	-e "/^[ \t#]*(config|default|depends|select|range)/{
		s,([ (!])(${nonfeature_symbols})($|[ )]),\1FREETZ_BUSYBOX_\2\3,g
		s,([ (!])(${nonfeature_symbols})($|[ )]),\1FREETZ_BUSYBOX_\2\3,g
	}" \
	"$BBOUT"
sed -i '/^mainmenu /d' "$BBOUT"
sed -i 's!\(^#*[\t ]*default \)y\(.*\)$!\1n\2!g;' "$BBOUT"

echo -n " finalizing ..."
echo -e "\n### Do not edit this file! Run generate.sh to create it. ###\n\n" > "$BBDEP"
sed -n 's/^config /$(PKG)_REBUILD_SUBOPTS += /p' "$BBOUT" | sort -u >> "$BBDEP"

default MD5SUM "y" # for modsave
default FEATURE_COPYBUF_KB 64
default FEATURE_VI_MAX_LEN 1024
default SUBST_WCHAR 0
default LAST_SUPPORTED_WCHAR 0
default BUSYBOX_EXEC_PATH "/bin/busybox"
default "Buffer allocation policy" FREETZ_BUSYBOX_FEATURE_BUFFERS_GO_ON_STACK
depends_on LOCALE_SUPPORT "!FREETZ_TARGET_UCLIBC_0_9_28"
depends_on FEATURE_IPV6 "FREETZ_TARGET_IPV6_SUPPORT"
depends_on KLOGD "FREETZ_AVM_HAS_PRINTK"
depends_on RFKILL "!FREETZ_KERNEL_VERSION_2_6_13"
depends_on WGET "!FREETZ_PACKAGE_WGET \|\| FREETZ_WGET_ALWAYS_AVAILABLE"
depends_on XZ "!FREETZ_PACKAGE_XZ"

depends_on UBIATTACH "FREETZ_KERNEL_VERSION_2_6_28_MIN"
depends_on UBIDETACH "FREETZ_KERNEL_VERSION_2_6_28_MIN"
depends_on UBIMKVOL "FREETZ_KERNEL_VERSION_2_6_28_MIN"
depends_on UBIRMVOL "FREETZ_KERNEL_VERSION_2_6_28_MIN"
depends_on UBIRSVOL "FREETZ_KERNEL_VERSION_2_6_28_MIN"
depends_on UBIUPDATEVOL "FREETZ_KERNEL_VERSION_2_6_28_MIN"

# Freetz mandatory options BUSYBOX_FEATURE_PS_LONG & BUSYBOX_FEATURE_PS_WIDE both depend on !DESKTOP.
# Make DESKTOP depend on some non-existing symbol to prevent the user from (accidentally) selecting it
# in Freetz menuconfig. This ensures (as a side effect) that "ps -l" is always available.
depends_on DESKTOP "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# from-file-to-file mode is supported since 2.6.33, thus disabled
depends_on FEATURE_USE_SENDFILE "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# SSL helper not available, thus disabled
depends_on FEATURE_WGET_SSL_HELPER "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

select_ FEATURE_WGET_OPENSSL "FREETZ_PACKAGE_OPENSSL"

echo " done."
