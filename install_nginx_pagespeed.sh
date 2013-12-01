#!/bin/bash
cd /usr/src
aptitude update
sudo apt-get install dpkg-dev git -y
sudo apt-get source nginx -y 
sudo apt-get build-dep nginx -y
git clone https://github.com/pagespeed/ngx_pagespeed.git
cd ngx_pagespeed
wget https://dl.google.com/dl/page-speed/psol/1.7.30.1.tar.gz
tar xvfz 1.7.30.1.tar.gz
cd /usr/src/nginx-1.*
patch -p1 -l <<'EOF'
--- old/debian/rules  2012-04-13 06:08:13.000000000 -0300
+++ new/debian/rules  2013-12-01 15:05:36.974256658 -0300
@@ -154,6 +154,7 @@
 	   --with-md5=/usr/include/openssl \
 	    --with-mail \
 	    --with-mail_ssl_module \
+	    --add-module=/usr/src/ngx_pagespeed \
 	    --add-module=$(MODULESDIR)/nginx-auth-pam \
 	    --add-module=$(MODULESDIR)/chunkin-nginx-module \
 	    --add-module=$(MODULESDIR)/headers-more-nginx-module \
EOF
dpkg-buildpackage -b
dpkg -i /usr/src/nginx-common_1.*all.deb
dpkg -i /usr/src/nginx-extras_1.*.deb
