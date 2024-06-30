-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/underline.js
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunction({
	type = "underline",
	names = { "\\underline" },
	props = { numArgs = 1, allowedInText = true },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		return {
			type = "underline",
			mode = parser.mode,
			body = args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}
	end,
	htmlBuilder = function(self, group, options)
		-- Underlines are handled in the TeXbook pg 443, Rule 10.
		-- Build the inner group.
		local innerGroup = html:buildGroup(group.body, options) -- Create the line to go below the body
		local line = buildCommon:makeLineSpan("underline-line", options) -- Generate the vlist, with the appropriate kerns
		local defaultRuleThickness = options:fontMetrics().defaultRuleThickness
		local vlist = buildCommon:makeVList({
			positionType = "top",
			positionData = innerGroup.height,
			children = {
				{ type = "kern", size = defaultRuleThickness },
				{ type = "elem", elem = line },
				{ type = "kern", size = 3 * defaultRuleThickness },
				{ type = "elem", elem = innerGroup },
			},
		}, options)
		return buildCommon:makeSpan({ "mord", "underline" }, { vlist }, options)
	end,
	mathmlBuilder = function(self, group, options)
		local operator = mathMLTree.MathNode.new("mo", { mathMLTree.TextNode.new("\u{203e}") })
		operator:setAttribute("stretchy", "true")
		local node =
			mathMLTree.MathNode.new("munder", { mml:buildGroup(group.body, options), operator })
		node:setAttribute("accentunder", "true")
		return node
	end,
})
