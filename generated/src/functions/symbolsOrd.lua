-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/symbolsOrd.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local RegExp = require(Packages.RegExp)
-- @flow
local defineFunctionBuilders = require(script.Parent.Parent.defineFunction).defineFunctionBuilders
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local mml = require(script.Parent.Parent.buildMathML)
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode -- "mathord" and "textord" ParseNodes created in Parser.js from symbol Groups in
-- src/symbols.js.
local defaultVariant: { [string]: string } =
	{ ["mi"] = "italic", ["mn"] = "normal", ["mtext"] = "normal" }
defineFunctionBuilders({
	type = "mathord",
	htmlBuilder = function(self, group, options)
		return buildCommon:makeOrd(group, options, "mathord")
	end,
	mathmlBuilder = function(self, group: ParseNode<"mathord">, options)
		local node =
			mathMLTree.MathNode.new("mi", { mml:makeText(group.text, group.mode, options) })
		local ref = mml:getVariant(group, options)
		local variant = Boolean.toJSBoolean(ref) and ref or "italic"
		if variant ~= defaultVariant[tostring(node.type)] then
			node:setAttribute("mathvariant", variant)
		end
		return node
	end,
})
defineFunctionBuilders({
	type = "textord",
	htmlBuilder = function(self, group, options)
		return buildCommon:makeOrd(group, options, "textord")
	end,
	mathmlBuilder = function(self, group: ParseNode<"textord">, options)
		local text = mml:makeText(group.text, group.mode, options)
		local ref = mml:getVariant(group, options)
		local variant = Boolean.toJSBoolean(ref) and ref or "normal"
		local node
		if group.mode == "text" then
			node = mathMLTree.MathNode.new("mtext", { text })
		elseif Boolean.toJSBoolean(RegExp("[0-9]"):test(group.text)) then
			node = mathMLTree.MathNode.new("mn", { text })
		elseif group.text == "\\prime" then
			node = mathMLTree.MathNode.new("mo", { text })
		else
			node = mathMLTree.MathNode.new("mi", { text })
		end
		if variant ~= defaultVariant[tostring(node.type)] then
			node:setAttribute("mathvariant", variant)
		end
		return node
	end,
})
