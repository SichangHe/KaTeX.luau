-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/accentunder.js
-- @flow
-- Horizontal overlap functions
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local stretchy = require(script.Parent.Parent.stretchy).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode
defineFunction({
	type = "accentUnder",
	names = {
		"\\underleftarrow",
		"\\underrightarrow",
		"\\underleftrightarrow",
		"\\undergroup",
		"\\underlinesegment",
		"\\utilde",
	},
	props = { numArgs = 1 },
	handler = function(ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local base = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return { type = "accentUnder", mode = parser.mode, label = funcName, base = base }
	end,
	htmlBuilder = function(group: ParseNode<"accentUnder">, options)
		-- Treat under accents much like underlines.
		local innerGroup = html:buildGroup(group.base, options)
		local accentBody = stretchy:svgSpan(group, options)
		local kern = if group.label == "\\utilde" then 0.12 else 0 -- Generate the vlist, with the appropriate kerns
		local vlist = buildCommon:makeVList({
			positionType = "top",
			positionData = innerGroup.height,
			children = {
				{ type = "elem", elem = accentBody, wrapperClasses = { "svg-align" } },
				{ type = "kern", size = kern },
				{ type = "elem", elem = innerGroup },
			},
		}, options)
		return buildCommon:makeSpan({ "mord", "accentunder" }, { vlist }, options)
	end,
	mathmlBuilder = function(group, options)
		local accentNode = stretchy:mathMLnode(group.label)
		local node =
			mathMLTree.MathNode.new("munder", { mml:buildGroup(group.base, options), accentNode })
		node:setAttribute("accentunder", "true")
		return node
	end,
})
