# Copyright 2013 Flexiant Ltd
#
# Written by Marco Meinardi
#
# This is an example script that shows how to read and parse
# metadata to configure a Wordpress instance. For the sake of
# simplicity, all error handling has been omitted.
# Not recommended for production use.
#
# The following parameters are read by the script:
#	- WP_website: the URL of the blog
#	- WP_adminpwd: the password for MySQL root and WP admin
#	- WP_adminemail: for Apache ServerAdmina and WP setting
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Read Metadata
WEBSITE=$(curl http://169.254.169.254/metadata 2>/dev/null |  xmllint --nocdata --xpath '//foreignkeys/key[@name="WP_website"]/text()' -)
ADMINPWD=$(curl http://169.254.169.254/metadata 2>/dev/null | xmllint --nocdata --xpath '//foreignkeys/key[@name="WP_adminpwd"]/text()' -)
ADMINEMAIL=$(curl http://169.254.169.254/metadata 2>/dev/null | xmllint --nocdata --xpath '//foreignkeys/key[@name="WP_adminemail"]/text()' -)

# Configure apache default virtualhost
sed -i.bak -e "s/ServerName/ServerName $WEBSITE/" /etc/apache2/sites-available/default >/dev/null
sed -i.bak -e "s/ServerAdmin/ServerAdmin $ADMINEMAIL/" /etc/apache2/sites-available/default >/dev/null
service apache2 restart

# Reset MySQL root default password to match with the Wordpress Admin password
service mysql stop
mysqld_safe --skip-grant-tables &
sleep 15
mysql -u root -e "UPDATE user SET Password=PASSWORD('$ADMINPWD') WHERE User='root';FLUSH PRIVILEGES;" mysql
killall -9 mysqld_safe
killall -9 mysqld
service mysql start
sleep 15

# Setup Wordpress database and configuration file
echo -e "\n127.0.0.1 $WEBSITE" >> /etc/hosts
bash /usr/share/doc/wordpress/examples/setup-mysql -n wordpress $WEBSITE >/dev/null
sleep 5

# POST values to the Wordpress web install wizard
ADMINEMAIL2=$(echo "$ADMINEMAIL" | sed -e "s/@/%40/")
curl -X POST -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:12.0) Gecko/20100101 Firefox/12.0" -e "http://$WEBSITE/wp-admin/install.php?step=2" -H "Content-
Type:application/x-www-form-urlencoded" -H "Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Accept-Encoding:gzip, deflate" --data "?w
eblog_title=$WEBSITE&user_name=admin&admin_password=$ADMINPWD&admin_password2=$ADMINPWD&admin_email=$ADMINEMAIL2&blog_public=1&Submit=Install+WordPress" http://$
WEBSITE/wp-admin/install.php?step=2 >/dev/null

# Clean rc.local
sed -i.bak -e "s/\/bin\/bash \/usr\/local\/bin\/wordpress_autoconf\.sh//" /etc/rc.local >/dev/null
