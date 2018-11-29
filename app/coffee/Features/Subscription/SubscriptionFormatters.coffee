dateformat = require 'dateformat'
settings = require "settings-sharelatex"


currenySymbols = 
	EUR: "€"	
	USD: "$"
	GBP: "£"
	SEK: "kr"
	CAD: "$"
	NOK: "kr"
	DKK: "kr"
	AUD: "$"
	NZD: "$"
	CHF: "Fr"
	SGD: "$"


module.exports =

	formatPrice: (priceInCents, currency = "USD") ->
		string = priceInCents + ""
		string = "0" + string if string.length == 2
		string = "00" + string if string.length == 1
		string = "000" if string.length == 0
		cents = string.slice(-2)
		dollars = string.slice(0, -2)
		symbol = currenySymbols[currency]
		return "#{symbol}#{dollars}.#{cents}"

	formatDate: (date) ->
		return null if !date?
		dateformat date, "dS mmmm yyyy"