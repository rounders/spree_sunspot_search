SpreeSunspotSearch
==================

Adds Solr search to Spree using [Sunspot](https://github.com/sunspot/sunspot).

This is compatible with Spree 1.3. I haven't tested it below that.


Install
=======

I make the assumption that you have a functioning Spree store and are just extending the search capabilities with Sunspot/Solr

Add spree_sunspot_search to your Gemfile and run bundler.

`gem 'spree_sunspot', github: 'rounders/spree_sunspot_search'`

add the following to the Gemfile if you are not using another solr install locally for testing and development. The rake tasks for starting and stop this for development are included automatically for your use.

	group :test, :development do
		gem 'sunspot_solr'
	end


Install the solr.yml file from Sunspot and the initializers

`rails g sunspot_rails:install`

Running
=======

Start up Solr (bundled with Sunspot's install)

`rake sunspot:solr:run`

Build the index for the first time

`rake sunspot:reindex`

Customise the Facets Shown
--------------------------

Edit the initializer and specify you Product Properties, Product Options, and Price Ranges as an array.
The initializer should provide enough examples to get you started.

Testing
=======

TODO


Authors
=======
* @jbrien
* @rounders

Copyright (c) 2012-13 John Brien Dilts, released under the New BSD License
