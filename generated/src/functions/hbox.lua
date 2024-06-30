-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/hbox.js
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML) -- \hbox is provided for compatibility with LaTeX \vcenter.
-- In LaTeX, \vcenter can act only on a box, as in
-- \vcenter{\hbox{$\frac{a+b}{\dfrac{c}{d}}$}}
-- This function by itself doesn't do anything but prevent a soft line break.
defineFunction({
	type = "hbox",
	names = { "\\hbox" },
	props = { numArgs = 1, argTypes = { "text" }, allowedInText = true, primitive = true },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		return {
			type = "hbox",
			mode = parser.mode,
			body = ordargument(args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
		}
	end,
	htmlBuilder = function(self, group, options)
		local elements = html:buildExpression(group.body, options, false)
		return buildCommon:makeFragment(elements)
	end,
	mathmlBuilder = function(self, group, options)
		return mathMLTree.MathNode.new("mrow", mml:buildExpression(group.body, options))
	end,
})
