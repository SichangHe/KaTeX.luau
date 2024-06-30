-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/text.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML) -- Non-mathy text, possibly in a font
local textFontFamilies = {
	["\\text"] = nil,
	["\\textrm"] = "textrm",
	["\\textsf"] = "textsf",
	["\\texttt"] = "texttt",
	["\\textnormal"] = "textrm",
}
local textFontWeights = { ["\\textbf"] = "textbf", ["\\textmd"] = "textmd" }
local textFontShapes = { ["\\textit"] = "textit", ["\\textup"] = "textup" }
local function optionsWithFont(group, options)
	local font = group.font -- Checks if the argument is a font family or a font style.
	if not Boolean.toJSBoolean(font) then
		return options
	elseif Boolean.toJSBoolean(textFontFamilies[tostring(font)]) then
		return options:withTextFontFamily(textFontFamilies[tostring(font)])
	elseif Boolean.toJSBoolean(textFontWeights[tostring(font)]) then
		return options:withTextFontWeight(textFontWeights[tostring(font)])
	else
		return options:withTextFontShape(textFontShapes[tostring(font)])
	end
end
defineFunction({
	type = "text",
	names = {
		-- Font families
		"\\text",
		"\\textrm",
		"\\textsf",
		"\\texttt",
		"\\textnormal",
		-- Font weights
		"\\textbf",
		"\\textmd",
		-- Font Shapes
		"\\textit",
		"\\textup",
	},
	props = { numArgs = 1, argTypes = { "text" }, allowedInArgument = true, allowedInText = true },
	handler = function(self, ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return { type = "text", mode = parser.mode, body = ordargument(body), font = funcName }
	end,
	htmlBuilder = function(self, group, options)
		local newOptions = optionsWithFont(group, options)
		local inner = html:buildExpression(group.body, newOptions, true)
		return buildCommon:makeSpan({ "mord", "text" }, inner, newOptions)
	end,
	mathmlBuilder = function(self, group, options)
		local newOptions = optionsWithFont(group, options)
		return mml:buildExpressionRow(group.body, newOptions)
	end,
})
