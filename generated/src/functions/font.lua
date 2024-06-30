-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/font.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Object = LuauPolyfill.Object
-- @flow
-- TODO(kevinb): implement \\sl and \\sc
local binrelClass = require(script.Parent.mclass).binrelClass
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local normalizeArgument = defineFunctionModule.normalizeArgument
local utils = require(script.Parent.Parent.utils).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode
local function htmlBuilder(group: ParseNode<"font">, options)
	local font = group.font
	local newOptions = options:withFont(font)
	return html:buildGroup(group.body, newOptions)
end
local function mathmlBuilder(group: ParseNode<"font">, options)
	local font = group.font
	local newOptions = options:withFont(font)
	return mml:buildGroup(group.body, newOptions)
end
local fontAliases = {
	["\\Bbb"] = "\\mathbb",
	["\\bold"] = "\\mathbf",
	["\\frak"] = "\\mathfrak",
	["\\bm"] = "\\boldsymbol",
}
defineFunction({
	type = "font",
	names = {
		-- styles, except \boldsymbol defined below
		"\\mathrm",
		"\\mathit",
		"\\mathbf",
		"\\mathnormal",
		-- families
		"\\mathbb",
		"\\mathcal",
		"\\mathfrak",
		"\\mathscr",
		"\\mathsf",
		"\\mathtt",
		-- aliases, except \bm defined below
		"\\Bbb",
		"\\bold",
		"\\frak",
	},
	props = { numArgs = 1, allowedInArgument = true },
	handler = function(ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local body = normalizeArgument(args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		])
		local func = funcName
		if Array.indexOf(Object.keys(fontAliases), tostring(func)) ~= -1 then
			func = fontAliases[tostring(func)]
		end
		return {
			type = "font",
			mode = parser.mode,
			font = Array.slice(func, 1),--[[ ROBLOX CHECK: check if 'func' is an Array ]]
			body = body,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineFunction({
	type = "mclass",
	names = { "\\boldsymbol", "\\bm" },
	props = { numArgs = 1 },
	handler = function(ref0, args)
		local parser = ref0.parser
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local isCharacterBox = utils:isCharacterBox(body) -- amsbsy.sty's \boldsymbol uses \binrel spacing to inherit the
		-- argument's bin|rel|ord status
		return {
			type = "mclass",
			mode = parser.mode,
			mclass = binrelClass(body),
			body = { { type = "font", mode = parser.mode, font = "boldsymbol", body = body } },
			isCharacterBox = isCharacterBox,
		}
	end,
}) -- Old font changing functions
defineFunction({
	type = "font",
	names = { "\\rm", "\\sf", "\\tt", "\\bf", "\\it", "\\cal" },
	props = { numArgs = 0, allowedInText = true },
	handler = function(ref0, args)
		local parser, funcName, breakOnTokenText = ref0.parser, ref0.funcName, ref0.breakOnTokenText
		local mode = parser.mode
		local body = parser:parseExpression(true, breakOnTokenText)
		local style = ("math%s"):format(
			tostring(Array.slice(funcName, 1) --[[ ROBLOX CHECK: check if 'funcName' is an Array ]])
		)
		return {
			type = "font",
			mode = mode,
			font = style,
			body = { type = "ordgroup", mode = parser.mode, body = body },
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
