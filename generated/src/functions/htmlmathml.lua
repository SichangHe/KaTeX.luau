-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/htmlmathml.js
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunction({
	type = "htmlmathml",
	names = { "\\html@mathml" },
	props = { numArgs = 2, allowedInText = true },
	handler = function(ref0, args)
		local parser = ref0.parser
		return {
			type = "htmlmathml",
			mode = parser.mode,
			html = ordargument(args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
			mathml = ordargument(args[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
		}
	end,
	htmlBuilder = function(group, options)
		local elements = html:buildExpression(group.html, options, false)
		return buildCommon:makeFragment(elements)
	end,
	mathmlBuilder = function(group, options)
		return mml:buildExpressionRow(group.mathml, options)
	end,
})
