-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/ordgroup.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
-- @flow
local defineFunctionBuilders = require(script.Parent.Parent.defineFunction).defineFunctionBuilders
local buildCommon = require(script.Parent.Parent.buildCommon).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunctionBuilders({
	type = "ordgroup",
	htmlBuilder = function(self, group, options)
		if Boolean.toJSBoolean(group.semisimple) then
			return buildCommon:makeFragment(html:buildExpression(group.body, options, false))
		end
		return buildCommon:makeSpan(
			{ "mord" },
			html:buildExpression(group.body, options, true),
			options
		)
	end,
	mathmlBuilder = function(self, group, options)
		return mml:buildExpressionRow(group.body, options, true)
	end,
})
