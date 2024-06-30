-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/environments/array.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local RegExp = require(Packages.RegExp)
local exports = {}
-- @flow
local buildCommon = require(script.Parent.Parent.buildCommon).default
local Style = require(script.Parent.Parent.Style).default
local defineEnvironment = require(script.Parent.Parent.defineEnvironment).default
local parseCD = require(script.Parent.cd).parseCD
local defineFunction = require(script.Parent.Parent.defineFunction).default
local defineMacro = require(script.Parent.Parent.defineMacro).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local ParseError = require(script.Parent.Parent.ParseError).default
local parseNodeModule = require(script.Parent.Parent.parseNode)
local assertNodeType = parseNodeModule.assertNodeType
local assertSymbolNodeType = parseNodeModule.assertSymbolNodeType
local checkSymbolNodeType = require(script.Parent.Parent.parseNode).checkSymbolNodeType
local Token = require(script.Parent.Parent.Token).Token
local unitsModule = require(script.Parent.Parent.units)
local calculateSize = unitsModule.calculateSize
local makeEm = unitsModule.makeEm
local utils = require(script.Parent.Parent.utils).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local parserModule = require(script.Parent.Parent.Parser)
type Parser = parserModule.default
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode
type AnyParseNode = parseNodeModule.AnyParseNode
local typesModule = require(script.Parent.Parent.types)
type StyleStr = typesModule.StyleStr
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
type HtmlBuilder = defineFunctionModule.HtmlBuilder
type MathMLBuilder = defineFunctionModule.MathMLBuilder
-- Data stored in the ParseNode associated with the environment.
export type AlignSpec =
	{ type: "separator", separator: string }
	| { type: "align", align: string, pregap: number?, postgap: number? }
-- Type to indicate column separation in MathML
export type ColSeparationType = "align" | "alignat" | "gather" | "small" | "CD"
-- Helper functions
local function getHLines(
	parser: Parser
): any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ boolean[] ]]
	-- Return an array. The array length = number of hlines.
	-- Each element in the array tells if the line is dashed.
	local hlineInfo = {}
	parser:consumeSpaces()
	local nxt = parser:fetch().text
	if nxt == "\\relax" then
		-- \relax is an artifact of the \cr macro below
		parser:consume()
		parser:consumeSpaces()
		nxt = parser:fetch().text
	end
	while nxt == "\\hline" or nxt == "\\hdashline" do
		parser:consume()
		table.insert(hlineInfo, nxt == "\\hdashline") --[[ ROBLOX CHECK: check if 'hlineInfo' is an Array ]]
		parser:consumeSpaces()
		nxt = parser:fetch().text
	end
	return hlineInfo
end
local function validateAmsEnvironmentContext(context)
	local settings_ = context.parser.settings
	if not Boolean.toJSBoolean(settings_.displayMode) then
		error(
			ParseError.new(
				("{%s} can be used only in"):format(tostring(context.envName)) .. " display mode."
			)
		)
	end
end
-- autoTag (an argument to parseArray) can be one of three values:
-- * undefined: Regular (not-top-level) array; no tags on each row
-- * true: Automatic equation numbering, overridable by \tag
-- * false: Tags allowed on each row, but no automatic numbering
-- This function *doesn't* work with the "split" environment name.
local function getAutoTag(name): boolean?
	if
		Array.indexOf(name, "ed") --[[ ROBLOX CHECK: check if 'name' is an Array ]]
		== -1
	then
		return Array.indexOf(name, "*") --[[ ROBLOX CHECK: check if 'name' is an Array ]]
			== -1
	end
	-- return undefined;
end
--[[*
 * Parse the body of the environment, with rows delimited by \\ and
 * columns delimited by &, and create a nested list in row-major order
 * with one group per cell.  If given an optional argument style
 * ("text", "display", etc.), then each cell is cast into that style.
 ]]
local function parseArray(
	parser: Parser,
	ref0: {
		hskipBeforeAndAfter: boolean?,
		addJot: boolean?,
		cols: any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ AlignSpec[] ]]?,
		arraystretch: number?,
		colSeparationType: ColSeparationType?,
		autoTag: boolean?,
		singleRow: boolean?,
		emptySingleRow: boolean?,
		maxNumCols: number?,
		leqno: boolean?,
	},
	style: StyleStr
): ParseNode<"array">
	local hskipBeforeAndAfter, addJot, cols, arraystretch, colSeparationType, autoTag, singleRow, emptySingleRow, maxNumCols, leqno =
		ref0.hskipBeforeAndAfter,
		ref0.addJot,
		ref0.cols,
		ref0.arraystretch,
		ref0.colSeparationType,
		ref0.autoTag,
		ref0.singleRow,
		ref0.emptySingleRow,
		ref0.maxNumCols,
		ref0.leqno
	parser.gullet:beginGroup()
	if not Boolean.toJSBoolean(singleRow) then
		-- \cr is equivalent to \\ without the optional size argument (see below)
		-- TODO: provide helpful error when \cr is used outside array environment
		parser.gullet.macros:set("\\cr", "\\\\\\relax")
	end
	-- Get current arraystretch if it's not set by the environment
	if not Boolean.toJSBoolean(arraystretch) then
		local stretch = parser.gullet:expandMacroAsText("\\arraystretch")
		if
			stretch == nil --[[ ROBLOX CHECK: loose equality used upstream ]]
		then
			-- Default \arraystretch from lttab.dtx
			arraystretch = 1
		else
			arraystretch = parseFloat(stretch)
			if
				not Boolean.toJSBoolean(arraystretch)
				or arraystretch < 0 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			then
				error(ParseError.new(("Invalid \\arraystretch: %s"):format(tostring(stretch))))
			end
		end
	end
	-- Start group for first cell
	parser.gullet:beginGroup()
	local row = {}
	local body = { row }
	local rowGaps = {}
	local hLinesBeforeRow = {}
	local tags = if autoTag ~= nil --[[ ROBLOX CHECK: loose inequality used upstream ]]
		then {}
		else nil
	-- amsmath uses \global\@eqnswtrue and \global\@eqnswfalse to represent
	-- whether this row should have an equation number.  Simulate this with
	-- a \@eqnsw macro set to 1 or 0.
	local function beginRow()
		if Boolean.toJSBoolean(autoTag) then
			parser.gullet.macros:set("\\@eqnsw", "1", true)
		end
	end
	local function endRow()
		if Boolean.toJSBoolean(tags) then
			if Boolean.toJSBoolean(parser.gullet.macros:get("\\df@tag")) then
				table.insert(tags, parser:subparse({ Token.new("\\df@tag") })) --[[ ROBLOX CHECK: check if 'tags' is an Array ]]
				parser.gullet.macros:set("\\df@tag", nil, true)
			else
				table.insert(
					tags,
					(function()
						local ref = Boolean(autoTag)
						return if Boolean.toJSBoolean(ref)
							then parser.gullet.macros:get("\\@eqnsw") == "1"
							else ref
					end)()
				) --[[ ROBLOX CHECK: check if 'tags' is an Array ]]
			end
		end
	end
	beginRow()
	-- Test for \hline at the top of the array.
	table.insert(hLinesBeforeRow, getHLines(parser)) --[[ ROBLOX CHECK: check if 'hLinesBeforeRow' is an Array ]]
	while true do
		-- eslint-disable-line no-constant-condition
		-- Parse each cell in its own group (namespace)
		local cell = parser:parseExpression(
			false,
			if Boolean.toJSBoolean(singleRow) then "\\end" else "\\\\"
		)
		parser.gullet:endGroup()
		parser.gullet:beginGroup()
		cell = { type = "ordgroup", mode = parser.mode, body = cell }
		if Boolean.toJSBoolean(style) then
			cell = { type = "styling", mode = parser.mode, style = style, body = { cell } }
		end
		table.insert(row, cell) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
		local next_ = parser:fetch().text
		if next_ == "&" then
			if
				Boolean.toJSBoolean(
					if Boolean.toJSBoolean(maxNumCols) then row.length == maxNumCols else maxNumCols
				)
			then
				if
					Boolean.toJSBoolean(
						Boolean.toJSBoolean(singleRow) and singleRow or colSeparationType
					)
				then
					-- {equation} or {split}
					error(ParseError.new("Too many tab characters: &", parser.nextToken))
				else
					-- {array} environment
					parser.settings:reportNonstrict(
						"textEnv",
						"Too few columns " .. "specified in the {array} column argument."
					)
				end
			end
			parser:consume()
		elseif next_ == "\\end" then
			endRow()
			-- Arrays terminate newlines with `\crcr` which consumes a `\cr` if
			-- the last line is empty.  However, AMS environments keep the
			-- empty row if it's the only one.
			-- NOTE: Currently, `cell` is the last item added into `row`.
			if
				row.length == 1
				and cell.type == "styling"
				and cell.body[
						1 --[[ ROBLOX adaptation: added 1 to array index ]]
					].body.length
					== 0
				and (
					body.length > 1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
					or not Boolean.toJSBoolean(emptySingleRow)
				)
			then
				table.remove(body) --[[ ROBLOX CHECK: check if 'body' is an Array ]]
			end
			if
				hLinesBeforeRow.length
				< body.length + 1 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			then
				table.insert(hLinesBeforeRow, {}) --[[ ROBLOX CHECK: check if 'hLinesBeforeRow' is an Array ]]
			end
			break
		elseif next_ == "\\\\" then
			parser:consume()
			local size
			-- \def\Let@{\let\\\math@cr}
			-- \def\math@cr{...\math@cr@}
			-- \def\math@cr@{\new@ifnextchar[\math@cr@@{\math@cr@@[\z@]}}
			-- \def\math@cr@@[#1]{...\math@cr@@@...}
			-- \def\math@cr@@@{\cr}
			if parser.gullet:future().text ~= " " then
				size = parser:parseSizeGroup(true)
			end
			table.insert(rowGaps, if Boolean.toJSBoolean(size) then size.value else nil) --[[ ROBLOX CHECK: check if 'rowGaps' is an Array ]]
			endRow()
			-- check for \hline(s) following the row separator
			table.insert(hLinesBeforeRow, getHLines(parser)) --[[ ROBLOX CHECK: check if 'hLinesBeforeRow' is an Array ]]
			row = {}
			table.insert(body, row) --[[ ROBLOX CHECK: check if 'body' is an Array ]]
			beginRow()
		else
			error(ParseError.new("Expected & or \\\\ or \\cr or \\end", parser.nextToken))
		end
	end
	-- End cell group
	parser.gullet:endGroup()
	-- End array group defining \cr
	parser.gullet:endGroup()
	return {
		type = "array",
		mode = parser.mode,
		addJot = addJot,
		arraystretch = arraystretch,
		body = body,
		cols = cols,
		rowGaps = rowGaps,
		hskipBeforeAndAfter = hskipBeforeAndAfter,
		hLinesBeforeRow = hLinesBeforeRow,
		colSeparationType = colSeparationType,
		tags = tags,
		leqno = leqno,
	}
end
-- Decides on a style for cells in an array according to whether the given
-- environment name starts with the letter 'd'.
local function dCellStyle(envName): StyleStr
	if
		Array.slice(envName, 0, 1) --[[ ROBLOX CHECK: check if 'envName' is an Array ]]
		== "d"
	then
		return "display"
	else
		return "text"
	end
end
type Outrow = {
	height: number,
	depth: number,
	pos: number,
	[number]: any,--[[ ROBLOX TODO: Unhandled node for type: ExistsTypeAnnotation ]]--[[ * ]]
}
local htmlBuilder: HtmlBuilder<"array">
function htmlBuilder(group, options)
	local r
	local c
	local nr = group.body.length
	local hLinesBeforeRow = group.hLinesBeforeRow
	local nc = 0
	local body = Array.new(nr)
	local hlines = {}
	local ruleThickness = math.max(
		options:fontMetrics().arrayRuleWidth,
		options.minRuleThickness -- User override.
	)
	-- Horizontal spacing
	local pt = 1 / options:fontMetrics().ptPerEm
	local arraycolsep = 5 * pt -- default value, i.e. \arraycolsep in article.cls
	if
		Boolean.toJSBoolean(
			if Boolean.toJSBoolean(group.colSeparationType)
				then group.colSeparationType == "small"
				else group.colSeparationType
		)
	then
		-- We're in a {smallmatrix}. Default column space is \thickspace,
		-- i.e. 5/18em = 0.2778em, per amsmath.dtx for {smallmatrix}.
		-- But that needs adjustment because LaTeX applies \scriptstyle to the
		-- entire array, including the colspace, but this function applies
		-- \scriptstyle only inside each element.
		local localMultiplier = options:havingStyle(Style.SCRIPT).sizeMultiplier
		arraycolsep = 0.2778 * (localMultiplier / options.sizeMultiplier)
	end
	-- Vertical spacing
	local baselineskip = if group.colSeparationType == "CD"
		then calculateSize({ number = 3, unit = "ex" }, options)
		else 12 * pt -- see size10.clo
	-- Default \jot from ltmath.dtx
	-- TODO(edemaine): allow overriding \jot via \setlength (#687)
	local jot = 3 * pt
	local arrayskip = group.arraystretch * baselineskip
	local arstrutHeight = 0.7 * arrayskip -- \strutbox in ltfsstrc.dtx and
	local arstrutDepth = 0.3 * arrayskip -- \@arstrutbox in lttab.dtx
	local totalHeight = 0
	-- Set a position for \hline(s) at the top of the array, if any.
	local function setHLinePos(
		hlinesInGap: any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ boolean[] ]]
	)
		do
			local i = 0
			while
				i
				< hlinesInGap.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				if
					i
					> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
				then
					totalHeight += 0.25
				end
				table.insert(hlines, { pos = totalHeight, isDashed = hlinesInGap[tostring(i)] }) --[[ ROBLOX CHECK: check if 'hlines' is an Array ]]
				i += 1
			end
		end
	end
	setHLinePos(hLinesBeforeRow[
		1 --[[ ROBLOX adaptation: added 1 to array index ]]
	])
	r = 0
	while
		r
		< group.body.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
	do
		local inrow = group.body[tostring(r)]
		local height = arstrutHeight -- \@array adds an \@arstrut
		local depth = arstrutDepth -- to each tow (via the template)
		if
			nc
			< inrow.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		then
			nc = inrow.length
		end
		local outrow: Outrow = Array.new(inrow.length) :: any
		c = 0
		while
			c
			< inrow.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			local elt = html:buildGroup(inrow[tostring(c)], options)
			if
				depth
				< elt.depth --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			then
				depth = elt.depth
			end
			if
				height
				< elt.height --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			then
				height = elt.height
			end
			outrow[tostring(c)] = elt
			c += 1
		end
		local rowGap = group.rowGaps[tostring(r)]
		local gap = 0
		if Boolean.toJSBoolean(rowGap) then
			gap = calculateSize(rowGap, options)
			if
				gap
				> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			then
				-- \@argarraycr
				gap += arstrutDepth
				if
					depth
					< gap --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
				then
					depth = gap -- \@xargarraycr
				end
				gap = 0
			end
		end
		-- In AMS multiline environments such as aligned and gathered, rows
		-- correspond to lines that have additional \jot added to the
		-- \baselineskip via \openup.
		if Boolean.toJSBoolean(group.addJot) then
			depth += jot
		end
		outrow.height = height
		outrow.depth = depth
		totalHeight += height
		outrow.pos = totalHeight
		totalHeight += depth + gap -- \@yargarraycr
		body[tostring(r)] = outrow
		-- Set a position for \hline(s), if any.
		setHLinePos(hLinesBeforeRow[tostring(r + 1)])
		r += 1
	end
	local offset = totalHeight / 2 + options:fontMetrics().axisHeight
	local colDescriptions = Boolean.toJSBoolean(group.cols) and group.cols or {}
	local cols = {}
	local colSep
	local colDescrNum
	local tagSpans = {}
	if
		Boolean.toJSBoolean(if Boolean.toJSBoolean(group.tags)
			then Array.some(group.tags, function(tag)
				return tag
			end) --[[ ROBLOX CHECK: check if 'group.tags' is an Array ]]
			else group.tags)
	then
		-- An environment with manual tags and/or automatic equation numbers.
		-- Create node(s), the latter of which trigger CSS counter increment.
		r = 0
		while
			r
			< nr --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			local rw = body[tostring(r)]
			local shift = rw.pos - offset
			local tag = group.tags[tostring(r)]
			local tagSpan
			if tag == true then
				-- automatic numbering
				tagSpan = buildCommon:makeSpan({ "eqn-num" }, {}, options)
			elseif tag == false then
				-- \nonumber/\notag or starred environment
				tagSpan = buildCommon:makeSpan({}, {}, options)
			else
				-- manual \tag
				tagSpan =
					buildCommon:makeSpan({}, html:buildExpression(tag, options, true), options)
			end
			tagSpan.depth = rw.depth
			tagSpan.height = rw.height
			table.insert(tagSpans, { type = "elem", elem = tagSpan, shift = shift }) --[[ ROBLOX CHECK: check if 'tagSpans' is an Array ]]
			r += 1
		end
	end
	c = 0
	colDescrNum = 0
	while -- Continue while either there are more columns or more column
		-- descriptions, so trailing separators don't get lost.
		-- Continue while either there are more columns or more column
		-- descriptions, so trailing separators don't get lost.
		c < nc --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		or colDescrNum < colDescriptions.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
	do
		local colDescr = Boolean.toJSBoolean(colDescriptions[tostring(colDescrNum)])
				and colDescriptions[tostring(colDescrNum)]
			or {}
		local firstSeparator = true
		while colDescr.type == "separator" do
			-- If there is more than one separator in a row, add a space
			-- between them.
			if not Boolean.toJSBoolean(firstSeparator) then
				colSep = buildCommon:makeSpan({ "arraycolsep" }, {})
				colSep.style.width = makeEm(options:fontMetrics().doubleRuleSep)
				table.insert(cols, colSep) --[[ ROBLOX CHECK: check if 'cols' is an Array ]]
			end
			if colDescr.separator == "|" or colDescr.separator == ":" then
				local lineType = if colDescr.separator == "|" then "solid" else "dashed"
				local separator = buildCommon:makeSpan({ "vertical-separator" }, {}, options)
				separator.style.height = makeEm(totalHeight)
				separator.style.borderRightWidth = makeEm(ruleThickness)
				separator.style.borderRightStyle = lineType
				separator.style.margin = ("0 %s"):format(tostring(makeEm(-ruleThickness / 2)))
				local shift = totalHeight - offset
				if Boolean.toJSBoolean(shift) then
					separator.style.verticalAlign = makeEm(-shift)
				end
				table.insert(cols, separator) --[[ ROBLOX CHECK: check if 'cols' is an Array ]]
			else
				error(ParseError.new("Invalid separator type: " .. tostring(colDescr.separator)))
			end
			colDescrNum += 1
			colDescr = Boolean.toJSBoolean(colDescriptions[tostring(colDescrNum)])
					and colDescriptions[tostring(colDescrNum)]
				or {}
			firstSeparator = false
		end
		if
			c
			>= nc --[[ ROBLOX CHECK: operator '>=' works only if either both arguments are strings or both are a number ]]
		then
			c += 1
			colDescrNum += 1
			continue
		end
		local sepwidth
		if
			Boolean.toJSBoolean(
				c > 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
					or group.hskipBeforeAndAfter
			)
		then
			sepwidth = utils:deflt(colDescr.pregap, arraycolsep)
			if sepwidth ~= 0 then
				colSep = buildCommon:makeSpan({ "arraycolsep" }, {})
				colSep.style.width = makeEm(sepwidth)
				table.insert(cols, colSep) --[[ ROBLOX CHECK: check if 'cols' is an Array ]]
			end
		end
		local col = {}
		r = 0
		while
			r
			< nr --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			local row = body[tostring(r)]
			local elem = row[tostring(c)]
			if not Boolean.toJSBoolean(elem) then
				r += 1
				continue
			end
			local shift = row.pos - offset
			elem.depth = row.depth
			elem.height = row.height
			table.insert(col, { type = "elem", elem = elem, shift = shift }) --[[ ROBLOX CHECK: check if 'col' is an Array ]]
			r += 1
		end
		col = buildCommon:makeVList({ positionType = "individualShift", children = col }, options)
		col = buildCommon:makeSpan({
			"col-align-" .. tostring(Boolean.toJSBoolean(colDescr.align) and colDescr.align or "c"),
		}, { col })
		table.insert(cols, col) --[[ ROBLOX CHECK: check if 'cols' is an Array ]]
		if
			Boolean.toJSBoolean(
				c < nc - 1 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
					or group.hskipBeforeAndAfter
			)
		then
			sepwidth = utils:deflt(colDescr.postgap, arraycolsep)
			if sepwidth ~= 0 then
				colSep = buildCommon:makeSpan({ "arraycolsep" }, {})
				colSep.style.width = makeEm(sepwidth)
				table.insert(cols, colSep) --[[ ROBLOX CHECK: check if 'cols' is an Array ]]
			end
		end
		c += 1
		colDescrNum += 1
	end
	body = buildCommon:makeSpan({ "mtable" }, cols)
	-- Add \hline(s), if any.
	if
		hlines.length
		> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	then
		local line = buildCommon:makeLineSpan("hline", options, ruleThickness)
		local dashes = buildCommon:makeLineSpan("hdashline", options, ruleThickness)
		local vListElems = { { type = "elem", elem = body, shift = 0 } }
		while
			hlines.length
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		do
			local hline = table.remove(hlines) --[[ ROBLOX CHECK: check if 'hlines' is an Array ]]
			local lineShift = hline.pos - offset
			if Boolean.toJSBoolean(hline.isDashed) then
				table.insert(vListElems, { type = "elem", elem = dashes, shift = lineShift }) --[[ ROBLOX CHECK: check if 'vListElems' is an Array ]]
			else
				table.insert(vListElems, { type = "elem", elem = line, shift = lineShift }) --[[ ROBLOX CHECK: check if 'vListElems' is an Array ]]
			end
		end
		body = buildCommon:makeVList(
			{ positionType = "individualShift", children = vListElems },
			options
		)
	end
	if tagSpans.length == 0 then
		return buildCommon:makeSpan({ "mord" }, { body }, options)
	else
		local eqnNumCol = buildCommon:makeVList(
			{ positionType = "individualShift", children = tagSpans },
			options
		)
		eqnNumCol = buildCommon:makeSpan({ "tag" }, { eqnNumCol }, options)
		return buildCommon:makeFragment({ body, eqnNumCol })
	end
end
local alignMap = { c = "center ", l = "left ", r = "right " }
local mathmlBuilder: MathMLBuilder<"array">
function mathmlBuilder(group, options)
	local tbl = {}
	local glue = mathMLTree.MathNode.new("mtd", {}, { "mtr-glue" })
	local tag = mathMLTree.MathNode.new("mtd", {}, { "mml-eqn-num" })
	do
		local i = 0
		while
			i
			< group.body.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			local rw = group.body[tostring(i)]
			local row = {}
			do
				local j = 0
				while
					j
					< rw.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
				do
					table.insert(
						row,
						mathMLTree.MathNode.new("mtd", { mml:buildGroup(rw[tostring(j)], options) })
					) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
					j += 1
				end
			end
			if
				Boolean.toJSBoolean(
					if Boolean.toJSBoolean(group.tags) then group.tags[tostring(i)] else group.tags
				)
			then
				table.insert(row, 1, glue) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
				table.insert(row, glue) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
				if Boolean.toJSBoolean(group.leqno) then
					table.insert(row, 1, tag) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
				else
					table.insert(row, tag) --[[ ROBLOX CHECK: check if 'row' is an Array ]]
				end
			end
			table.insert(tbl, mathMLTree.MathNode.new("mtr", row)) --[[ ROBLOX CHECK: check if 'tbl' is an Array ]]
			i += 1
		end
	end
	local table_ = mathMLTree.MathNode.new("mtable", tbl)
	-- Set column alignment, row spacing, column spacing, and
	-- array lines by setting attributes on the table element.
	-- Set the row spacing. In MathML, we specify a gap distance.
	-- We do not use rowGap[] because MathML automatically increases
	-- cell height with the height/depth of the element content.
	-- LaTeX \arraystretch multiplies the row baseline-to-baseline distance.
	-- We simulate this by adding (arraystretch - 1)em to the gap. This
	-- does a reasonable job of adjusting arrays containing 1 em tall content.
	-- The 0.16 and 0.09 values are found empirically. They produce an array
	-- similar to LaTeX and in which content does not interfere with \hlines.
	local gap = if group.arraystretch == 0.5
		then 0.1 -- {smallmatrix}, {subarray}
		else 0.16 + group.arraystretch - 1 + (if Boolean.toJSBoolean(group.addJot)
			then 0.09
			else 0)
	table_:setAttribute("rowspacing", makeEm(gap))
	-- MathML table lines go only between cells.
	-- To place a line on an edge we'll use <menclose>, if necessary.
	local menclose = ""
	local align = ""
	if
		Boolean.toJSBoolean(if Boolean.toJSBoolean(group.cols)
			then group.cols.length
				> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			else group.cols)
	then
		-- Find column alignment, column spacing, and  vertical lines.
		local cols = group.cols
		local columnLines = ""
		local prevTypeWasAlign = false
		local iStart = 0
		local iEnd = cols.length
		if
			cols[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			].type == "separator"
		then
			menclose ..= "top "
			iStart = 1
		end
		if cols[tostring(cols.length - 1)].type == "separator" then
			menclose ..= "bottom "
			iEnd -= 1
		end
		do
			local i = iStart
			while
				i
				< iEnd --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				if cols[tostring(i)].type == "align" then
					align += alignMap[tostring(cols[tostring(i)].align)]
					if Boolean.toJSBoolean(prevTypeWasAlign) then
						columnLines ..= "none "
					end
					prevTypeWasAlign = true
				elseif cols[tostring(i)].type == "separator" then
					-- MathML accepts only single lines between cells.
					-- So we read only the first of consecutive separators.
					if Boolean.toJSBoolean(prevTypeWasAlign) then
						columnLines ..= if cols[tostring(i)].separator == "|"
							then "solid "
							else "dashed "
						prevTypeWasAlign = false
					end
				end
				i += 1
			end
		end
		table_:setAttribute("columnalign", align:trim())
		if Boolean.toJSBoolean(RegExp("[sd]"):test(columnLines)) then
			table_:setAttribute("columnlines", columnLines:trim())
		end
	end
	-- Set column spacing.
	if group.colSeparationType == "align" then
		local cols = Boolean.toJSBoolean(group.cols) and group.cols or {}
		local spacing = ""
		do
			local i = 1
			while
				i
				< cols.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				spacing ..= if Boolean.toJSBoolean(i % 2) then "0em " else "1em "
				i += 1
			end
		end
		table_:setAttribute("columnspacing", spacing:trim())
	elseif group.colSeparationType == "alignat" or group.colSeparationType == "gather" then
		table_:setAttribute("columnspacing", "0em")
	elseif group.colSeparationType == "small" then
		table_:setAttribute("columnspacing", "0.2778em")
	elseif group.colSeparationType == "CD" then
		table_:setAttribute("columnspacing", "0.5em")
	else
		table_:setAttribute("columnspacing", "1em")
	end
	-- Address \hline and \hdashline
	local rowLines = ""
	local hlines = group.hLinesBeforeRow
	menclose ..= if hlines[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		].length
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then "left "
		else ""
	menclose ..= if hlines[tostring(hlines.length - 1)].length
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then "right "
		else ""
	do
		local i = 1
		while
			i
			< hlines.length - 1 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			rowLines ..= if hlines[tostring(i)].length == 0
				then "none "
				-- MathML accepts only a single line between rows. Read one element.
				else if Boolean.toJSBoolean(hlines[tostring(i)][
						1 --[[ ROBLOX adaptation: added 1 to array index ]]
					])
					then "dashed "
					else "solid "
			i += 1
		end
	end
	if Boolean.toJSBoolean(RegExp("[sd]"):test(rowLines)) then
		table_:setAttribute("rowlines", rowLines:trim())
	end
	if menclose ~= "" then
		table_ = mathMLTree.MathNode.new("menclose", { table_ })
		table_:setAttribute("notation", menclose:trim())
	end
	if
		Boolean.toJSBoolean(if Boolean.toJSBoolean(group.arraystretch)
			then group.arraystretch
				< 1 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			else group.arraystretch)
	then
		-- A small array. Wrap in scriptstyle so row gap is not too large.
		table_ = mathMLTree.MathNode.new("mstyle", { table_ })
		table_:setAttribute("scriptlevel", "1")
	end
	return table_
end
-- Convenience function for align, align*, aligned, alignat, alignat*, alignedat.
local function alignedHandler(context, args)
	if
		Array.indexOf(context.envName, "ed") --[[ ROBLOX CHECK: check if 'context.envName' is an Array ]]
		== -1
	then
		validateAmsEnvironmentContext(context)
	end
	local cols = {}
	local separationType = if Array.indexOf(context.envName, "at") --[[ ROBLOX CHECK: check if 'context.envName' is an Array ]]
			> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then "alignat"
		else "align"
	local isSplit = context.envName == "split"
	local res = parseArray(context.parser, {
		cols = cols,
		addJot = true,
		autoTag = if Boolean.toJSBoolean(isSplit) then nil else getAutoTag(context.envName),
		emptySingleRow = true,
		colSeparationType = separationType,
		maxNumCols = if Boolean.toJSBoolean(isSplit) then 2 else nil,
		leqno = context.parser.settings.leqno,
	}, "display")
	-- Determining number of columns.
	-- 1. If the first argument is given, we use it as a number of columns,
	--    and makes sure that each row doesn't exceed that number.
	-- 2. Otherwise, just count number of columns = maximum number
	--    of cells in each row ("aligned" mode -- isAligned will be true).
	--
	-- At the same time, prepend empty group {} at beginning of every second
	-- cell in each row (starting with second cell) so that operators become
	-- binary.  This behavior is implemented in amsmath's \start@aligned.
	local numMaths
	local numCols = 0
	local emptyGroup = { type = "ordgroup", mode = context.mode, body = {} }
	if
		Boolean.toJSBoolean(if Boolean.toJSBoolean(args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			])
			then args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			].type == "ordgroup"
			else args[1])
	then
		local arg0 = ""
		do
			local i = 0
			while
				i
				< args[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				].body.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				local textord = assertNodeType(
					args[
						1 --[[ ROBLOX adaptation: added 1 to array index ]]
					].body[tostring(i)],
					"textord"
				)
				arg0 += textord.text
				i += 1
			end
		end
		numMaths = Number(arg0)
		numCols = numMaths * 2
	end
	local isAligned = not Boolean.toJSBoolean(numCols)
	Array.forEach(res.body, function(row)
		do
			local i = 1
			while
				i
				< row.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				-- Modify ordgroup node within styling node
				local styling = assertNodeType(row[tostring(i)], "styling")
				local ordgroup = assertNodeType(
					styling.body[
						1 --[[ ROBLOX adaptation: added 1 to array index ]]
					],
					"ordgroup"
				)
				table.insert(ordgroup.body, 1, emptyGroup) --[[ ROBLOX CHECK: check if 'ordgroup.body' is an Array ]]
				i += 2
			end
		end
		if not Boolean.toJSBoolean(isAligned) then
			-- Case 1
			local curMaths = row.length / 2
			if
				numMaths
				< curMaths --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			then
				error(
					ParseError.new(
						"Too many math in a row: "
							.. ("expected %s, but got %s"):format(
								tostring(numMaths),
								tostring(curMaths)
							),
						row[
							1 --[[ ROBLOX adaptation: added 1 to array index ]]
						]
					)
				)
			end
		elseif
			numCols
			< row.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		then
			-- Case 2
			numCols = row.length
		end
	end) --[[ ROBLOX CHECK: check if 'res.body' is an Array ]]
	-- Adjusting alignment.
	-- In aligned mode, we add one \qquad between columns;
	-- otherwise we add nothing.
	do
		local i = 0
		while
			i
			< numCols --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			local align = "r"
			local pregap = 0
			if i % 2 == 1 then
				align = "l"
			elseif
				Boolean.toJSBoolean(
					i > 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
						and isAligned
				)
			then
				-- "aligned" mode.
				pregap = 1 -- add one \quad
			end
			cols[tostring(i)] = { type = "align", align = align, pregap = pregap, postgap = 0 }
			i += 1
		end
	end
	res.colSeparationType = if Boolean.toJSBoolean(isAligned) then "align" else "alignat"
	return res
end
-- Arrays are part of LaTeX, defined in lttab.dtx so its documentation
-- is part of the source2e.pdf file of LaTeX2e source documentation.
-- {darray} is an {array} environment where cells are set in \displaystyle,
-- as defined in nccmath.sty.
defineEnvironment({
	type = "array",
	names = { "array", "darray" },
	props = { numArgs = 1 },
	handler = function(self, context, args)
		-- Since no types are specified above, the two possibilities are
		-- - The argument is wrapped in {} or [], in which case Parser's
		--   parseGroup() returns an "ordgroup" wrapping some symbol node.
		-- - The argument is a bare symbol node.
		local symNode = checkSymbolNodeType(args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		])
		local colalign: any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ AnyParseNode[] ]] = if Boolean.toJSBoolean(
				symNode
			)
			then {
				args[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
			}
			else assertNodeType(
				args[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
				"ordgroup"
			).body
		local cols = Array.map(colalign, function(nde)
			local node = assertSymbolNodeType(nde)
			local ca = node.text
			if
				Array.indexOf("lcr", ca) --[[ ROBLOX CHECK: check if '"lcr"' is an Array ]]
				~= -1
			then
				return { type = "align", align = ca }
			elseif ca == "|" then
				return { type = "separator", separator = "|" }
			elseif ca == ":" then
				return { type = "separator", separator = ":" }
			end
			error(ParseError.new("Unknown column alignment: " .. tostring(ca), nde))
		end) --[[ ROBLOX CHECK: check if 'colalign' is an Array ]]
		local res = {
			cols = cols,
			hskipBeforeAndAfter = true,
			-- \@preamble in lttab.dtx
			maxNumCols = cols.length,
		}
		return parseArray(context.parser, res, dCellStyle(context.envName))
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
-- The matrix environments of amsmath builds on the array environment
-- of LaTeX, which is discussed above.
-- The mathtools package adds starred versions of the same environments.
-- These have an optional argument to choose left|center|right justification.
defineEnvironment({
	type = "array",
	names = {
		"matrix",
		"pmatrix",
		"bmatrix",
		"Bmatrix",
		"vmatrix",
		"Vmatrix",
		"matrix*",
		"pmatrix*",
		"bmatrix*",
		"Bmatrix*",
		"vmatrix*",
		"Vmatrix*",
	},
	props = { numArgs = 0 },
	handler = function(self, context)
		local delimiters = ({
			["matrix"] = nil,
			["pmatrix"] = { "(", ")" },
			["bmatrix"] = { "[", "]" },
			["Bmatrix"] = { "\\{", "\\}" },
			["vmatrix"] = { "|", "|" },
			["Vmatrix"] = { "\\Vert", "\\Vert" },
		})[tostring(context.envName:replace("*", ""))]
		-- \hskip -\arraycolsep in amsmath
		local colAlign = "c"
		local payload =
			{ hskipBeforeAndAfter = false, cols = { { type = "align", align = colAlign } } }
		if context.envName:charAt(context.envName.length - 1) == "*" then
			-- It's one of the mathtools starred functions.
			-- Parse the optional alignment argument.
			local parser = context.parser
			parser:consumeSpaces()
			if parser:fetch().text == "[" then
				parser:consume()
				parser:consumeSpaces()
				colAlign = parser:fetch().text
				if
					Array.indexOf("lcr", colAlign) --[[ ROBLOX CHECK: check if '"lcr"' is an Array ]]
					== -1
				then
					error(ParseError.new("Expected l or c or r", parser.nextToken))
				end
				parser:consume()
				parser:consumeSpaces()
				parser:expect("]")
				parser:consume()
				payload.cols = { { type = "align", align = colAlign } }
			end
		end
		local res: ParseNode<"array"> =
			parseArray(context.parser, payload, dCellStyle(context.envName))
		-- Populate cols with the correct number of column alignment specs.
		local numCols = math.max(
			0,
			table.unpack(Array.spread(Array.map(res.body, function(row)
				return row.length
			end) --[[ ROBLOX CHECK: check if 'res.body' is an Array ]]))
		)
		res.cols = Array.new(numCols):fill({ type = "align", align = colAlign })
		return if Boolean.toJSBoolean(delimiters)
			then {
				type = "leftright",
				mode = context.mode,
				body = { res },
				left = delimiters[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
				right = delimiters[
					2 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
				rightColor = nil, -- \right uninfluenced by \color in array
			}
			else res
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineEnvironment({
	type = "array",
	names = { "smallmatrix" },
	props = { numArgs = 0 },
	handler = function(self, context)
		local payload = { arraystretch = 0.5 }
		local res = parseArray(context.parser, payload, "script")
		res.colSeparationType = "small"
		return res
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineEnvironment({
	type = "array",
	names = { "subarray" },
	props = { numArgs = 1 },
	handler = function(self, context, args)
		-- Parsing of {subarray} is similar to {array}
		local symNode = checkSymbolNodeType(args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		])
		local colalign: any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ AnyParseNode[] ]] = if Boolean.toJSBoolean(
				symNode
			)
			then {
				args[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
			}
			else assertNodeType(
				args[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
				"ordgroup"
			).body
		local cols = Array.map(colalign, function(nde)
			local node = assertSymbolNodeType(nde)
			local ca = node.text
			-- {subarray} only recognizes "l" & "c"
			if
				Array.indexOf("lc", ca) --[[ ROBLOX CHECK: check if '"lc"' is an Array ]]
				~= -1
			then
				return { type = "align", align = ca }
			end
			error(ParseError.new("Unknown column alignment: " .. tostring(ca), nde))
		end) --[[ ROBLOX CHECK: check if 'colalign' is an Array ]]
		if
			cols.length
			> 1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			error(ParseError.new("{subarray} can contain only one column"))
		end
		local res = { cols = cols, hskipBeforeAndAfter = false, arraystretch = 0.5 }
		res = parseArray(context.parser, res, "script")
		if
			res.body.length > 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			and res.body[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				].length
				> 1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			error(ParseError.new("{subarray} can contain only one column"))
		end
		return res
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
-- A cases environment (in amsmath.sty) is almost equivalent to
-- \def\arraystretch{1.2}%
-- \left\{\begin{array}{@{}l@{\quad}l@{}} … \end{array}\right.
-- {dcases} is a {cases} environment where cells are set in \displaystyle,
-- as defined in mathtools.sty.
-- {rcases} is another mathtools environment. It's brace is on the right side.
defineEnvironment({
	type = "array",
	names = { "cases", "dcases", "rcases", "drcases" },
	props = { numArgs = 0 },
	handler = function(self, context)
		local payload = {
			arraystretch = 1.2,
			cols = {
				{
					type = "align",
					align = "l",
					pregap = 0,
					-- TODO(kevinb) get the current style.
					-- For now we use the metrics for TEXT style which is what we were
					-- doing before.  Before attempting to get the current style we
					-- should look at TeX's behavior especially for \over and matrices.
					postgap = 1.0,--[[ 1em quad ]]
				},
				{ type = "align", align = "l", pregap = 0, postgap = 0 },
			},
		}
		local res: ParseNode<"array"> =
			parseArray(context.parser, payload, dCellStyle(context.envName))
		return {
			type = "leftright",
			mode = context.mode,
			body = { res },
			left = if Array.indexOf(context.envName, "r") --[[ ROBLOX CHECK: check if 'context.envName' is an Array ]]
					> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
				then "."
				else "\\{",
			right = if Array.indexOf(context.envName, "r") --[[ ROBLOX CHECK: check if 'context.envName' is an Array ]]
					> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
				then "\\}"
				else ".",
			rightColor = nil,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
-- In the align environment, one uses ampersands, &, to specify number of
-- columns in each row, and to locate spacing between each column.
-- align gets automatic numbering. align* and aligned do not.
-- The alignedat environment can be used in math mode.
-- Note that we assume \nomallineskiplimit to be zero,
-- so that \strut@ is the same as \strut.
defineEnvironment({
	type = "array",
	names = { "align", "align*", "aligned", "split" },
	props = { numArgs = 0 },
	handler = alignedHandler,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
-- A gathered environment is like an array environment with one centered
-- column, but where rows are considered lines so get \jot line spacing
-- and contents are set in \displaystyle.
defineEnvironment({
	type = "array",
	names = { "gathered", "gather", "gather*" },
	props = { numArgs = 0 },
	handler = function(self, context)
		if Boolean.toJSBoolean(utils:contains({ "gather", "gather*" }, context.envName)) then
			validateAmsEnvironmentContext(context)
		end
		local res = {
			cols = { { type = "align", align = "c" } },
			addJot = true,
			colSeparationType = "gather",
			autoTag = getAutoTag(context.envName),
			emptySingleRow = true,
			leqno = context.parser.settings.leqno,
		}
		return parseArray(context.parser, res, "display")
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
-- alignat environment is like an align environment, but one must explicitly
-- specify maximum number of columns in each row, and can adjust spacing between
-- each columns.
defineEnvironment({
	type = "array",
	names = { "alignat", "alignat*", "alignedat" },
	props = { numArgs = 1 },
	handler = alignedHandler,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineEnvironment({
	type = "array",
	names = { "equation", "equation*" },
	props = { numArgs = 0 },
	handler = function(self, context)
		validateAmsEnvironmentContext(context)
		local res = {
			autoTag = getAutoTag(context.envName),
			emptySingleRow = true,
			singleRow = true,
			maxNumCols = 1,
			leqno = context.parser.settings.leqno,
		}
		return parseArray(context.parser, res, "display")
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineEnvironment({
	type = "array",
	names = { "CD" },
	props = { numArgs = 0 },
	handler = function(self, context)
		validateAmsEnvironmentContext(context)
		return parseCD(context.parser)
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineMacro("\\nonumber", "\\gdef\\@eqnsw{0}")
defineMacro("\\notag", "\\nonumber")
-- Catch \hline outside array environment
defineFunction({
	type = "text",
	-- Doesn't matter what this is.
	names = { "\\hline", "\\hdashline" },
	props = { numArgs = 0, allowedInText = true, allowedInMath = true },
	handler = function(self, context, args)
		error(
			ParseError.new(
				("%s valid only within array environment"):format(tostring(context.funcName))
			)
		)
	end,
})
return exports
