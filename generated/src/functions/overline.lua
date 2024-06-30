-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/overline.js
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunction({
	type = "overline",
	names = { "\\overline" },
	props = { numArgs = 1 },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return { type = "overline", mode = parser.mode, body = body }
	end,
	htmlBuilder = function(self, group, options)
		-- Overlines are handled in the TeXbook pg 443, Rule 9.
		-- Build the inner group in the cramped style.
		local innerGroup = html:buildGroup(group.body, options:havingCrampedStyle()) -- Create the line above the body
		local line = buildCommon:makeLineSpan("overline-line", options) -- Generate the vlist, with the appropriate kerns
		local defaultRuleThickness = options:fontMetrics().defaultRuleThickness
		local vlist = buildCommon:makeVList({
			positionType = "firstBaseline",
			children = {
				{ type = "elem", elem = innerGroup },
				{ type = "kern", size = 3 * defaultRuleThickness },
				{ type = "elem", elem = line },
				{ type = "kern", size = defaultRuleThickness },
			},
		}, options)
		return buildCommon:makeSpan({ "mord", "overline" }, { vlist }, options)
	end,
	mathmlBuilder = function(self, group, options)
		local operator = mathMLTree.MathNode.new("mo", { mathMLTree.TextNode.new("\u{203e}") })
		operator:setAttribute("stretchy", "true")
		local node =
			mathMLTree.MathNode.new("mover", { mml:buildGroup(group.body, options), operator })
		node:setAttribute("accent", "true")
		return node
	end,
})
