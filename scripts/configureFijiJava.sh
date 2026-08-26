#!/bin/bash
<<'README'
Defines configureFijiJava(), which finds the Java runtime bundled with the
FSDB-managed Fiji installation.

The helper exports:
  FIJI_JAVA      Absolute path to Fiji's java or java.exe executable
  FIJI_JAVA_BIN  Directory containing FIJI_JAVA

FIJI_JAVA_BIN is appended to PATH. It is deliberately not prepended, so an
existing system Java keeps precedence. The helper does not install Java and
does not modify the persistent system environment.

This file is intended to be sourced by FSDB scripts which actually need Java.
FIJIDIR must already have been defined, normally through getVar.sh.
README

#fsdb-rev-date: 260826

configureFijiJava() {
	if [[ -z "${FIJIDIR:-}" ]]; then
		printf 'ERROR: FIJIDIR is not defined; cannot locate Fiji bundled Java.\n' >&2
		return 1
	fi

	if [[ ! -d "$FIJIDIR/java" ]]; then
		printf "ERROR: Fiji Java directory does not exist: %s\n" "$FIJIDIR/java" >&2
		return 1
	fi

	FIJI_JAVA=$(find "$FIJIDIR/java" -path '*/bin/*' \
		\( -name java -o -name java.exe \) -executable -print -quit 2>/dev/null)

	if [[ -z "$FIJI_JAVA" ]]; then
		printf "ERROR: Cannot find Fiji bundled Java below: %s\n" "$FIJIDIR/java" >&2
		return 1
	fi

	FIJI_JAVA_BIN=$(dirname -- "$FIJI_JAVA")

	case ":${PATH:-}:" in
		*":${FIJI_JAVA_BIN}:"*) ;;
		*) PATH="${PATH:+${PATH}:}${FIJI_JAVA_BIN}" ;;
	esac

	export FIJI_JAVA FIJI_JAVA_BIN PATH
}
