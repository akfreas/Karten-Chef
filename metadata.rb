name             'karten'
maintainer       'YOUR_COMPANY_NAME'
maintainer_email 'YOUR_EMAIL'
license          'All rights reserved'
description      'Installs/Configures karten'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'


%w(apt postgresql database application application_nginx supervisor).each do |d|
    depends d
end
