-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/mclass.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local exports = {}
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local utils = require(script.Parent.Parent.utils).default
local parseNodeModule = require(script.Parent.Parent.parseNode)
type AnyParseNode = parseNodeModule.AnyParseNode
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode
local makeSpan = buildCommon.makeSpan
local function htmlBuilder(group: ParseNode<"mclass">, options)
	local elements = html:buildExpression(group.body, options, true)
	return makeSpan({ group.mclass }, elements, options)
end
local function mathmlBuilder(group: ParseNode<"mclass">, options)
	local node: mathMLTree_MathNode
	local inner = mml:buildExpression(group.body, options)
	if group.mclass == "minner" then
		node = mathMLTree.MathNode.new("mpadded", inner)
	elseif group.mclass == "mord" then
		if Boolean.toJSBoolean(group.isCharacterBox) then
			node = inner[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]
			node.type = "mi"
		else
			node = mathMLTree.MathNode.new("mi", inner)
		end
	else
		if Boolean.toJSBoolean(group.isCharacterBox) then
			node = inner[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]
			node.type = "mo"
		else
			node = mathMLTree.MathNode.new("mo", inner)
		end -- Set spacing based on what is the most likely adjacent atom type.
		-- See TeXbook p170.
		if group.mclass == "mbin" then
			node.attributes.lspace = "0.22em" -- medium space
			node.attributes.rspace = "0.22em"
		elseif group.mclass == "mpunct" then
			node.attributes.lspace = "0em"
			node.attributes.rspace = "0.17em" -- thinspace
		elseif group.mclass == "mopen" or group.mclass == "mclose" then
			node.attributes.lspace = "0em"
			node.attributes.rspace = "0em"
		elseif group.mclass == "minner" then
			node.attributes.lspace = "0.0556em" -- 1 mu is the most likely option
			node.attributes.width = "+0.1111em"
		end -- MathML <mo> default space is 5/18 em, so <mrel> needs no action.
		-- Ref: https://developer.mozilla.org/en-US/docs/Web/MathML/Element/mo
	end
	return node
end -- Math class commands except \mathop
defineFunction({
	type = "mclass",
	names = {
		"\\mathord",
		"\\mathbin",
		"\\mathrel",
		"\\mathopen",
		"\\mathclose",
		"\\mathpunct",
		"\\mathinner",
	},
	props = { numArgs = 1, primitive = true },
	handler = function(self, ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return {
			type = "mclass",
			mode = parser.mode,
			mclass = "m"
				.. tostring(
					Array.slice(funcName, 5) --[[ ROBLOX CHECK: check if 'funcName' is an Array ]]
				),
			-- TODO(kevinb): don't prefix with 'm'
			body = ordargument(body),
			isCharacterBox = utils:isCharacterBox(body),
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
local function binrelClass(arg: AnyParseNode): string
	-- \binrel@ spacing varies with (bin|rel|ord) of the atom in the argument.
	-- (by rendering separately and with {}s before and after, and measuring
	-- the change in spacing).  We'll do roughly the same by detecting the
	-- atom type directly.
	local atom = if Boolean.toJSBoolean(arg.type == "ordgroup" and arg.body.length)
		then arg.body[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		else arg
	if atom.type == "atom" and (atom.family == "bin" or atom.family == "rel") then
		return "m" .. tostring(atom.family)
	else
		return "mord"
	end
end
exports.binrelClass = binrelClass -- \@binrel{x}{y} renders like y but as mbin/mrel/mord if x is mbin/mrel/mord.
-- This is equivalent to \binrel@{x}\binrel@@{y} in AMSTeX.
defineFunction({
	type = "mclass",
	names = { "\\@binrel" },
	props = { numArgs = 2 },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		return {
			type = "mclass",
			mode = parser.mode,
			mclass = binrelClass(args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
			body = ordargument(args[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
			isCharacterBox = utils:isCharacterBox(args[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
		}
	end,
}) -- Build a relation or stacked op by placing one symbol on top of another
defineFunction({
	type = "mclass",
	names = { "\\stackrel", "\\overset", "\\underset" },
	props = { numArgs = 2 },
	handler = function(self, ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local baseArg = args[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local shiftedArg = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local mclass
		if funcName ~= "\\stackrel" then
			-- LaTeX applies \binrel spacing to \overset and \underset.
			mclass = binrelClass(baseArg)
		else
			mclass = "mrel" -- for \stackrel
		end
		local baseOp = {
			type = "op",
			mode = baseArg.mode,
			limits = true,
			alwaysHandleSupSub = true,
			parentIsSupSub = false,
			symbol = false,
			suppressBaseShift = funcName ~= "\\stackrel",
			body = ordargument(baseArg),
		}
		local supsub = {
			type = "supsub",
			mode = shiftedArg.mode,
			base = baseOp,
			sup = if funcName == "\\underset" then nil else shiftedArg,
			sub = if funcName == "\\underset" then shiftedArg else nil,
		}
		return {
			type = "mclass",
			mode = parser.mode,
			mclass = mclass,
			body = { supsub },
			isCharacterBox = utils:isCharacterBox(supsub),
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
return exports
