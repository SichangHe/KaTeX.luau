-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/environments/cd.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local exports = {}
-- @flow
local buildCommon = require(script.Parent.Parent.buildCommon).default
local defineFunction = require(script.Parent.Parent.defineFunction).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local assertSymbolNodeType = require(script.Parent.Parent.parseNode).assertSymbolNodeType
local ParseError = require(script.Parent.Parent.ParseError).default
local makeEm = require(script.Parent.Parent.units).makeEm
local parserModule = require(script.Parent.Parent.Parser)
type Parser = parserModule.default
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode
type AnyParseNode = parseNodeModule.AnyParseNode
local cdArrowFunctionName = {
	[">"] = "\\\\cdrightarrow",
	["<"] = "\\\\cdleftarrow",
	["="] = "\\\\cdlongequal",
	["A"] = "\\uparrow",
	["V"] = "\\downarrow",
	["|"] = "\\Vert",
	["."] = "no arrow",
}
local function newCell()
	-- Create an empty cell, to be filled below with parse nodes.
	-- The parseTree from this module must be constructed like the
	-- one created by parseArray(), so an empty CD cell must
	-- be a ParseNode<"styling">. And CD is always displaystyle.
	-- So these values are fixed and flow can do implicit typing.
	return { type = "styling", body = {}, mode = "math", style = "display" }
end
local function isStartOfArrow(node: AnyParseNode)
	return node.type == "textord" and node.text == "@"
end
local function isLabelEnd(node: AnyParseNode, endChar: string): boolean
	return (node.type == "mathord" or node.type == "atom") and node.text == endChar
end
local function cdArrow(
	arrowChar: string,
	labels: any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ ParseNode<"ordgroup">[] ]],
	parser: Parser
): AnyParseNode
	-- Return a parse tree of an arrow and its labels.
	-- This acts in a way similar to a macro expansion.
	local funcName = cdArrowFunctionName[tostring(arrowChar)]
	local condition_ = funcName
	if condition_ == "\\\\cdrightarrow" or condition_ == "\\\\cdleftarrow" then
		return parser:callFunction(funcName, {
			labels[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}, {
			labels[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		})
	elseif condition_ == "\\uparrow" or condition_ == "\\downarrow" then
		do
			local leftLabel = parser:callFunction("\\\\cdleft", {
				labels[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
			}, {})
			local bareArrow = { type = "atom", text = funcName, mode = "math", family = "rel" }
			local sizedArrow = parser:callFunction("\\Big", { bareArrow }, {})
			local rightLabel = parser:callFunction("\\\\cdright", {
				labels[
					2 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
			}, {})
			local arrowGroup =
				{ type = "ordgroup", mode = "math", body = { leftLabel, sizedArrow, rightLabel } }
			return parser:callFunction("\\\\cdparent", { arrowGroup }, {})
		end
	elseif condition_ == "\\\\cdlongequal" then
		return parser:callFunction("\\\\cdlongequal", {}, {})
	elseif condition_ == "\\Vert" then
		do
			local arrow = { type = "textord", text = "\\Vert", mode = "math" }
			return parser:callFunction("\\Big", { arrow }, {})
		end
	else
		return { type = "textord", text = " ", mode = "math" }
	end
end
local function parseCD(parser: Parser): ParseNode<"array">
	-- Get the array's parse nodes with \\ temporarily mapped to \cr.
	local parsedRows: any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ AnyParseNode[][] ]] =
		{}
	parser.gullet:beginGroup()
	parser.gullet.macros:set("\\cr", "\\\\\\relax")
	parser.gullet:beginGroup()
	while true do
		-- eslint-disable-line no-constant-condition
		-- Get the parse nodes for the next row.
		table.insert(parsedRows, parser:parseExpression(false, "\\\\")) --[[ ROBLOX CHECK: check if 'parsedRows' is an Array ]]
		parser.gullet:endGroup()
		parser.gullet:beginGroup()
		local next_ = parser:fetch().text
		if next_ == "&" or next_ == "\\\\" then
			parser:consume()
		elseif next_ == "\\end" then
			if parsedRows[tostring(parsedRows.length - 1)].length == 0 then
				table.remove(parsedRows) --[[ ROBLOX CHECK: check if 'parsedRows' is an Array ]] -- final row ended in \\
			end
			break
		else
			error(ParseError.new("Expected \\\\ or \\cr or \\end", parser.nextToken))
		end
	end
	local row = {}
	local body = { row } -- Loop thru the parse nodes. Collect them into cells and arrows.
	do
		local i = 0
		while
			i
			< parsedRows.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			-- Start a new row.
			local rowNodes = parsedRows[tostring(i)] -- Create the first cell.
			local cell = newCell()
			do
				local j = 0
				while
					j
					< rowNodes.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
				do
					if not Boolean.toJSBoolean(isStartOfArrow(rowNodes[tostring(j)])) then
						-- If a parseNode is not an arrow, it goes into a cell.
						table.insert(cell.body, rowNodes[tostring(j)]) --[[ ROBLOX CHECK: check if 'cell.body' is an Array ]]
					else
						-- Parse node j is an "@", the start of an arrow.
						-- Before starting on the arrow, push the cell into `row`.
						table.insert(row, cell) --[[ ROBLOX CHECK: check if 'row' is an Array ]] -- Now collect parseNodes into an arrow.
						-- The character after "@" defines the arrow type.
						j += 1
						local arrowChar = assertSymbolNodeType(rowNodes[tostring(j)]).text -- Create two empty label nodes. We may or may not use them.
						local labels: any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ ParseNode<"ordgroup">[] ]] =
							Array.new(2)
						labels[
							1 --[[ ROBLOX adaptation: added 1 to array index ]]
						] =
							{ type = "ordgroup", mode = "math", body = {} }
						labels[
							2 --[[ ROBLOX adaptation: added 1 to array index ]]
						] =
							{ type = "ordgroup", mode = "math", body = {} } -- Process the arrow.
						if
							Array.indexOf("=|.", arrowChar) --[[ ROBLOX CHECK: check if '"=|."' is an Array ]]
							> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
						then
						-- Three "arrows", ``@=`, `@|`, and `@.`, do not take labels.
						-- Do nothing here.
						elseif
							Array.indexOf("<>AV", arrowChar) --[[ ROBLOX CHECK: check if '"<>AV"' is an Array ]]
							> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
						then
							-- Four arrows, `@>>>`, `@<<<`, `@AAA`, and `@VVV`, each take
							-- two optional labels. E.g. the right-point arrow syntax is
							-- really:  @>{optional label}>{optional label}>
							-- Collect parseNodes into labels.
							do
								local labelNum = 0
								while
									labelNum
									< 2 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
								do
									local inLabel = true
									do
										local k = j + 1
										while
											k
											< rowNodes.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
										do
											if
												Boolean.toJSBoolean(
													isLabelEnd(rowNodes[tostring(k)], arrowChar)
												)
											then
												inLabel = false
												j = k
												break
											end
											if
												Boolean.toJSBoolean(
													isStartOfArrow(rowNodes[tostring(k)])
												)
											then
												error(
													ParseError.new(
														"Missing a "
															.. tostring(arrowChar)
															.. " character to complete a CD arrow.",
														rowNodes[tostring(k)]
													)
												)
											end
											table.insert(
												labels[tostring(labelNum)].body,
												rowNodes[tostring(k)]
											) --[[ ROBLOX CHECK: check if 'labels[labelNum].body' is an Array ]]
											k += 1
										end
									end
									if Boolean.toJSBoolean(inLabel) then
										-- isLabelEnd never returned a true.
										error(
											ParseError.new(
												"Missing a "
													.. tostring(arrowChar)
													.. " character to complete a CD arrow.",
												rowNodes[tostring(j)]
											)
										)
									end
									labelNum += 1
								end
							end
						else
							error(
								ParseError.new(
									'Expected one of "<>AV=|." after @',
									rowNodes[tostring(j)]
								)
							)
						end -- Now join the arrow to its labels.
						local arrow: AnyParseNode = cdArrow(arrowChar, labels, parser) -- Wrap the arrow in  ParseNode<"styling">.
						-- This is done to match parseArray() behavior.
						local wrappedArrow = {
							type = "styling",
							body = { arrow },
							mode = "math",
							style = "display", -- CD is always displaystyle.
						}
						table.insert(row, wrappedArrow) --[[ ROBLOX CHECK: check if 'row' is an Array ]] -- In CD's syntax, cells are implicit. That is, everything that
						-- is not an arrow gets collected into a cell. So create an empty
						-- cell now. It will collect upcoming parseNodes.
						cell = newCell()
					end
					j += 1
				end
			end
			if i % 2 == 0 then
				-- Even-numbered rows consist of: cell, arrow, cell, arrow, ... cell
				-- The last cell is not yet pushed into `row`, so:
				table.insert(row, cell) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
			else
				-- Odd-numbered rows consist of: vert arrow, empty cell, ... vert arrow
				-- Remove the empty cell that was placed at the beginning of `row`.
				table.remove(row, 1) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
			end
			row = {}
			table.insert(body, row) --[[ ROBLOX CHECK: check if 'body' is an Array ]]
			i += 1
		end
	end -- End row group
	parser.gullet:endGroup() -- End array group defining \\
	parser.gullet:endGroup() -- define column separation.
	local cols = Array.new(body[
		1 --[[ ROBLOX adaptation: added 1 to array index ]]
	].length):fill({
		type = "align",
		align = "c",
		pregap = 0.25,
		-- CD package sets \enskip between columns.
		postgap = 0.25, -- So pre and post each get half an \enskip, i.e. 0.25em.
	})
	return {
		type = "array",
		mode = "math",
		body = body,
		arraystretch = 1,
		addJot = true,
		rowGaps = { nil },
		cols = cols,
		colSeparationType = "CD",
		hLinesBeforeRow = Array.new(body.length + 1):fill({}),
	}
end
exports.parseCD = parseCD -- The functions below are not available for general use.
-- They are here only for internal use by the {CD} environment in placing labels
-- next to vertical arrows.
-- We don't need any such functions for horizontal arrows because we can reuse
-- the functionality that already exists for extensible arrows.
defineFunction({
	type = "cdlabel",
	names = { "\\\\cdleft", "\\\\cdright" },
	props = { numArgs = 1 },
	handler = function(self, ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		return {
			type = "cdlabel",
			mode = parser.mode,
			side = Array.slice(funcName, 4),--[[ ROBLOX CHECK: check if 'funcName' is an Array ]]
			label = args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}
	end,
	htmlBuilder = function(self, group, options)
		local newOptions = options:havingStyle(options.style:sup())
		local label =
			buildCommon:wrapFragment(html:buildGroup(group.label, newOptions, options), options)
		table.insert(label.classes, "cd-label-" .. tostring(group.side)) --[[ ROBLOX CHECK: check if 'label.classes' is an Array ]]
		label.style.bottom = makeEm(0.8 - label.depth) -- Zero out label height & depth, so vertical align of arrow is set
		-- by the arrow height, not by the label.
		label.height = 0
		label.depth = 0
		return label
	end,
	mathmlBuilder = function(self, group, options)
		local label = mathMLTree.MathNode.new("mrow", { mml:buildGroup(group.label, options) })
		label = mathMLTree.MathNode.new("mpadded", { label })
		label:setAttribute("width", "0")
		if group.side == "left" then
			label:setAttribute("lspace", "-1width")
		end -- We have to guess at vertical alignment. We know the arrow is 1.8em tall,
		-- But we don't know the height or depth of the label.
		label:setAttribute("voffset", "0.7em")
		label = mathMLTree.MathNode.new("mstyle", { label })
		label:setAttribute("displaystyle", "false")
		label:setAttribute("scriptlevel", "1")
		return label
	end,
})
defineFunction({
	type = "cdlabelparent",
	names = { "\\\\cdparent" },
	props = { numArgs = 1 },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		return {
			type = "cdlabelparent",
			mode = parser.mode,
			fragment = args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}
	end,
	htmlBuilder = function(self, group, options)
		-- Wrap the vertical arrow and its labels.
		-- The parent gets position: relative. The child gets position: absolute.
		-- So CSS can locate the label correctly.
		local parent = buildCommon:wrapFragment(html:buildGroup(group.fragment, options), options)
		table.insert(parent.classes, "cd-vert-arrow") --[[ ROBLOX CHECK: check if 'parent.classes' is an Array ]]
		return parent
	end,
	mathmlBuilder = function(self, group, options)
		return mathMLTree.MathNode.new("mrow", { mml:buildGroup(group.fragment, options) })
	end,
})
return exports
