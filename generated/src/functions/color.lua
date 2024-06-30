-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/color.js
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local parseNodeModule = require(script.Parent.Parent.parseNode)
type AnyParseNode = parseNodeModule.AnyParseNode
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local function htmlBuilder(group, options)
	local elements = html:buildExpression(group.body, options:withColor(group.color), false)
	-- \color isn't supposed to affect the type of the elements it contains.
	-- To accomplish this, we wrap the results in a fragment, so the inner
	-- elements will be able to directly interact with their neighbors. For
	-- example, `\color{red}{2 +} 3` has the same spacing as `2 + 3`
	return buildCommon:makeFragment(elements)
end
local function mathmlBuilder(group, options)
	local inner = mml:buildExpression(group.body, options:withColor(group.color))
	local node = mathMLTree.MathNode.new("mstyle", inner)
	node:setAttribute("mathcolor", group.color)
	return node
end
defineFunction({
	type = "color",
	names = { "\\textcolor" },
	props = { numArgs = 2, allowedInText = true, argTypes = { "color", "original" } },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		local color = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"color-token"
		).color
		local body = args[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return {
			type = "color",
			mode = parser.mode,
			color = color,
			body = ordargument(body) :: any,--[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]]--[[ AnyParseNode[] ]]
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineFunction({
	type = "color",
	names = { "\\color" },
	props = { numArgs = 1, allowedInText = true, argTypes = { "color" } },
	handler = function(self, ref0, args)
		local parser, breakOnTokenText = ref0.parser, ref0.breakOnTokenText
		local color = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"color-token"
		).color
		-- Set macro \current@color in current namespace to store the current
		-- color, mimicking the behavior of color.sty.
		-- This is currently used just to correctly color a \right
		-- that follows a \color command.
		parser.gullet.macros:set("\\current@color", color)
		-- Parse out the implicit body that should be colored.
		local body: any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ AnyParseNode[] ]] =
			parser:parseExpression(true, breakOnTokenText)
		return { type = "color", mode = parser.mode, color = color, body = body }
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
