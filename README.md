## Getting started

+ Setup dictybase oracle instance from binary dump files.

    For details email <dictybase@northwestern.edu>

+ Start an instance of dictybase blast server

  It is available as a vmware VM. For details email <dictybase@northwestern.edu>
  
+ Checkout this codebase from github,  preferably use the master or release branch.

    ```git clone git://github.com/dictyBase/DictyTools.git```
    
+ Make log folder

     ```mkdir log```
     
+ __Install dependencies__

  Using [perlbrew](http://perlbrew.pl/) with
  [cpanm](https://metacpan.org/module/App::cpanminus) is recommended.
  
     ```cpanm --installdeps .```
     
+ Create temporary folders for keeping blast search results and images.

     ```perl Build.PL && ./Build create_temp_folders```
     
+ __Create a new config file for development mode__

     ```cp config/dictytools.sample.yaml config/development.yaml```
     
  Change the values as needed particularly setup the proper database credentials and the
  location of dictybase blast server. Most of
  configuration parameters are well commented inside the file.

+ Start the standalone server

     ```script/dictytools daemon```


## Deployment

+ Start the plack FCGI backend 

    ```MOJO_MODE=production script/fcgi_backends.pl start production.server```
    
+ __Deploy with apache__

  Install the [fastcgi](http://www.fastcgi.com/mod_fastcgi/docs/mod_fastcgi.html) module
  Include the partial config file in the main config file.
  
  ```    Include <path_to_application_project>/deploy/apache.conf```
  
  Web application should be available from **http://yourhost/tools**
  
+ __Deploy with nginx__

  No config file yet,  but look at plack example,  should be similar.


