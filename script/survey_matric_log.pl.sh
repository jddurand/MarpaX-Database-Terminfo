#!/bin/sh
lwp-request http://metabase.cpantesters.org/tail/log.txt|grep Terminfo
