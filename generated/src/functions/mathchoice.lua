-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/mathchoice.js
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local Style = require(script.Parent.Parent.Style).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode
local function chooseMathStyle(group: ParseNode<"mathchoice">, options)
	local condition_ = options.style.size
	if condition_ == Style.DISPLAY.size then
		return group.display
	elseif condition_ == Style.TEXT.size then
		return group.text
	elseif condition_ == Style.SCRIPT.size then
		return group.script
	elseif condition_ == Style.SCRIPTSCRIPT.size then
		return group.scriptscript
	else
		return group.text
	end
end
defineFunction({
	type = "mathchoice",
	names = { "\\mathchoice" },
	props = { numArgs = 4, primitive = true },
	handler = function(ref0, args)
		local parser = ref0.parser
		return {
			type = "mathchoice",
			mode = parser.mode,
			display = ordargument(args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
			text = ordargument(args[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
			script = ordargument(args[
				3 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
			scriptscript = ordargument(args[
				4 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
		}
	end,
	htmlBuilder = function(group, options)
		local body = chooseMathStyle(group, options)
		local elements = html:buildExpression(body, options, false)
		return buildCommon:makeFragment(elements)
	end,
	mathmlBuilder = function(group, options)
		local body = chooseMathStyle(group, options)
		return mml:buildExpressionRow(body, options)
	end,
})
