#!/bin/bash
export DISPLAY=:99
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
