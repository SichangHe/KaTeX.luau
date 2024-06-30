-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/raisebox.js
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local calculateSize = require(script.Parent.Parent.units).calculateSize
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML) -- Box manipulation
defineFunction({
	type = "raisebox",
	names = { "\\raisebox" },
	props = { numArgs = 2, argTypes = { "size", "hbox" }, allowedInText = true },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		local amount = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"size"
		).value
		local body = args[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return { type = "raisebox", mode = parser.mode, dy = amount, body = body }
	end,
	htmlBuilder = function(self, group, options)
		local body = html:buildGroup(group.body, options)
		local dy = calculateSize(group.dy, options)
		return buildCommon:makeVList({
			positionType = "shift",
			positionData = -dy,
			children = { { type = "elem", elem = body } },
		}, options)
	end,
	mathmlBuilder = function(self, group, options)
		local node = mathMLTree.MathNode.new("mpadded", { mml:buildGroup(group.body, options) })
		local dy = group.dy.number + group.dy.unit
		node:setAttribute("voffset", dy)
		return node
	end,
})
