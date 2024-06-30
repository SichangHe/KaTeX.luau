-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/vcenter.js
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML) -- \vcenter:  Vertically center the argument group on the math axis.
defineFunction({
	type = "vcenter",
	names = { "\\vcenter" },
	props = {
		numArgs = 1,
		argTypes = { "original" },
		-- In LaTeX, \vcenter can act only on a box.
		allowedInText = false,
	},
	handler = function(self, ref0, args)
		local parser = ref0.parser
		return {
			type = "vcenter",
			mode = parser.mode,
			body = args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}
	end,
	htmlBuilder = function(self, group, options)
		local body = html:buildGroup(group.body, options)
		local axisHeight = options:fontMetrics().axisHeight
		local dy = 0.5 * (body.height - axisHeight - (body.depth + axisHeight))
		return buildCommon:makeVList({
			positionType = "shift",
			positionData = dy,
			children = { { type = "elem", elem = body } },
		}, options)
	end,
	mathmlBuilder = function(self, group, options)
		-- There is no way to do this in MathML.
		-- Write a class as a breadcrumb in case some post-processor wants
		-- to perform a vcenter adjustment.
		return mathMLTree.MathNode.new(
			"mpadded",
			{ mml:buildGroup(group.body, options) },
			{ "vcenter" }
		)
	end,
})
