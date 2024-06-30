-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/phantom.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunction({
	type = "phantom",
	names = { "\\phantom" },
	props = { numArgs = 1, allowedInText = true },
	handler = function(ref0, args)
		local parser = ref0.parser
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return { type = "phantom", mode = parser.mode, body = ordargument(body) }
	end,
	htmlBuilder = function(group, options)
		local elements = html:buildExpression(group.body, options:withPhantom(), false) -- \phantom isn't supposed to affect the elements it contains.
		-- See "color" for more details.
		return buildCommon:makeFragment(elements)
	end,
	mathmlBuilder = function(group, options)
		local inner = mml:buildExpression(group.body, options)
		return mathMLTree.MathNode.new("mphantom", inner)
	end,
})
defineFunction({
	type = "hphantom",
	names = { "\\hphantom" },
	props = { numArgs = 1, allowedInText = true },
	handler = function(ref0, args)
		local parser = ref0.parser
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return { type = "hphantom", mode = parser.mode, body = body }
	end,
	htmlBuilder = function(group, options)
		local node = buildCommon:makeSpan(
			{},
			{ html:buildGroup(group.body, options:withPhantom()) }
		)
		node.height = 0
		node.depth = 0
		if Boolean.toJSBoolean(node.children) then
			do
				local i = 0
				while
					i
					< node.children.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
				do
					node.children[tostring(i)].height = 0
					node.children[tostring(i)].depth = 0
					i += 1
				end
			end
		end -- See smash for comment re: use of makeVList
		node = buildCommon:makeVList(
			{ positionType = "firstBaseline", children = { { type = "elem", elem = node } } },
			options
		) -- For spacing, TeX treats \smash as a math group (same spacing as ord).
		return buildCommon:makeSpan({ "mord" }, { node }, options)
	end,
	mathmlBuilder = function(group, options)
		local inner = mml:buildExpression(ordargument(group.body), options)
		local phantom = mathMLTree.MathNode.new("mphantom", inner)
		local node = mathMLTree.MathNode.new("mpadded", { phantom })
		node:setAttribute("height", "0px")
		node:setAttribute("depth", "0px")
		return node
	end,
})
defineFunction({
	type = "vphantom",
	names = { "\\vphantom" },
	props = { numArgs = 1, allowedInText = true },
	handler = function(ref0, args)
		local parser = ref0.parser
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return { type = "vphantom", mode = parser.mode, body = body }
	end,
	htmlBuilder = function(group, options)
		local inner = buildCommon:makeSpan(
			{ "inner" },
			{ html:buildGroup(group.body, options:withPhantom()) }
		)
		local fix = buildCommon:makeSpan({ "fix" }, {})
		return buildCommon:makeSpan({ "mord", "rlap" }, { inner, fix }, options)
	end,
	mathmlBuilder = function(group, options)
		local inner = mml:buildExpression(ordargument(group.body), options)
		local phantom = mathMLTree.MathNode.new("mphantom", inner)
		local node = mathMLTree.MathNode.new("mpadded", { phantom })
		node:setAttribute("width", "0px")
		return node
	end,
})
