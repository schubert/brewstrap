Brewstrap
=========

OSX Homebrew + RVM + Chef Solo

    curl -L http://git.io/PvkgGw > /tmp/brewstrap.sh && bash /tmp/brewstrap.sh

If a solo.rb file is not present in your repo brewstrap will write one out expecting cookbooks only to be in the "cookbooks" folder. If you have additional folders you wish to include (for example site-cookbooks if you are using Librarian Chef) then check in your own solo.rb:

    file_cache_path '/tmp/chef-solo-brewstrap'
    cookbook_path '/tmp/chef/cookbooks', '/tmp/chef/site-cookbooks'

If a Cheffile from Librarian Chef is present, brewstrap will install the librarian-chef gem and then attempt to run "librarian-chef install" before launching chef solo.

* Homebrew: https://github.com/mxcl/homebrew
* RVM: http://rvm.beginrescueend.com/
* Chef: http://wiki.opscode.com/display/chef/Resources
* Librarian Chef: https://github.com/applicationsonline/librarian

