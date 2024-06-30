-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/enclose.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local RegExp = require(Packages.RegExp)
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local utils = require(script.Parent.Parent.utils).default
local stretchy = require(script.Parent.Parent.stretchy).default
local phasePath = require(script.Parent.Parent.svgGeometry).phasePath
local domTreeModule = require(script.Parent.Parent.domTree)
local PathNode = domTreeModule.PathNode
local SvgNode = domTreeModule.SvgNode
local unitsModule = require(script.Parent.Parent.units)
local calculateSize = unitsModule.calculateSize
local makeEm = unitsModule.makeEm
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local function htmlBuilder(group, options)
	-- \cancel, \bcancel, \xcancel, \sout, \fbox, \colorbox, \fcolorbox, \phase
	-- Some groups can return document fragments.  Handle those by wrapping
	-- them in a span.
	local inner = buildCommon:wrapFragment(html:buildGroup(group.body, options), options)
	local label = Array.slice(group.label, 1) --[[ ROBLOX CHECK: check if 'group.label' is an Array ]]
	local scale = options.sizeMultiplier
	local img
	local imgShift = 0 -- In the LaTeX cancel package, line geometry is slightly different
	-- depending on whether the subject is wider than it is tall, or vice versa.
	-- We don't know the width of a group, so as a proxy, we test if
	-- the subject is a single character. This captures most of the
	-- subjects that should get the "tall" treatment.
	local isSingleChar = utils:isCharacterBox(group.body)
	if label == "sout" then
		img = buildCommon:makeSpan({ "stretchy", "sout" })
		img.height = options:fontMetrics().defaultRuleThickness / scale
		imgShift = -0.5 * options:fontMetrics().xHeight
	elseif label == "phase" then
		-- Set a couple of dimensions from the steinmetz package.
		local lineWeight = calculateSize({ number = 0.6, unit = "pt" }, options)
		local clearance = calculateSize({ number = 0.35, unit = "ex" }, options) -- Prevent size changes like \Huge from affecting line thickness
		local newOptions = options:havingBaseSizing()
		scale = scale / newOptions.sizeMultiplier
		local angleHeight = inner.height + inner.depth + lineWeight + clearance -- Reserve a left pad for the angle.
		inner.style.paddingLeft = makeEm(angleHeight / 2 + lineWeight) -- Create an SVG
		local viewBoxHeight = math.floor(1000 * angleHeight * scale)
		local path = phasePath(viewBoxHeight)
		local svgNode = SvgNode.new({ PathNode.new("phase", path) }, {
			["width"] = "400em",
			["height"] = makeEm(viewBoxHeight / 1000),
			["viewBox"] = ("0 0 400000 %s"):format(tostring(viewBoxHeight)),
			["preserveAspectRatio"] = "xMinYMin slice",
		}) -- Wrap it in a span with overflow: hidden.
		img = buildCommon:makeSvgSpan({ "hide-tail" }, { svgNode }, options)
		img.style.height = makeEm(angleHeight)
		imgShift = inner.depth + lineWeight + clearance
	else
		-- Add horizontal padding
		if Boolean.toJSBoolean(RegExp("cancel"):test(label)) then
			if not Boolean.toJSBoolean(isSingleChar) then
				table.insert(inner.classes, "cancel-pad") --[[ ROBLOX CHECK: check if 'inner.classes' is an Array ]]
			end
		elseif label == "angl" then
			table.insert(inner.classes, "anglpad") --[[ ROBLOX CHECK: check if 'inner.classes' is an Array ]]
		else
			table.insert(inner.classes, "boxpad") --[[ ROBLOX CHECK: check if 'inner.classes' is an Array ]]
		end -- Add vertical padding
		local topPad = 0
		local bottomPad = 0
		local ruleThickness = 0 -- ref: cancel package: \advance\totalheight2\p@ % "+2"
		if Boolean.toJSBoolean(RegExp("box"):test(label)) then
			ruleThickness = math.max(
				options:fontMetrics().fboxrule, -- default
				options.minRuleThickness -- User override.
			)
			topPad = options:fontMetrics().fboxsep
				+ (if label == "colorbox" then 0 else ruleThickness)
			bottomPad = topPad
		elseif label == "angl" then
			ruleThickness =
				math.max(options:fontMetrics().defaultRuleThickness, options.minRuleThickness)
			topPad = 4 * ruleThickness -- gap = 3 × line, plus the line itself.
			bottomPad = math.max(0, 0.25 - inner.depth)
		else
			topPad = if Boolean.toJSBoolean(isSingleChar) then 0.2 else 0
			bottomPad = topPad
		end
		img = stretchy:encloseSpan(inner, label, topPad, bottomPad, options)
		if Boolean.toJSBoolean(RegExp("fbox|boxed|fcolorbox"):test(label)) then
			img.style.borderStyle = "solid"
			img.style.borderWidth = makeEm(ruleThickness)
		elseif label == "angl" and ruleThickness ~= 0.049 then
			img.style.borderTopWidth = makeEm(ruleThickness)
			img.style.borderRightWidth = makeEm(ruleThickness)
		end
		imgShift = inner.depth + bottomPad
		if Boolean.toJSBoolean(group.backgroundColor) then
			img.style.backgroundColor = group.backgroundColor
			if Boolean.toJSBoolean(group.borderColor) then
				img.style.borderColor = group.borderColor
			end
		end
	end
	local vlist
	if Boolean.toJSBoolean(group.backgroundColor) then
		vlist = buildCommon:makeVList({
			positionType = "individualShift",
			children = {
				-- Put the color background behind inner;
				{ type = "elem", elem = img, shift = imgShift },
				{ type = "elem", elem = inner, shift = 0 },
			},
		}, options)
	else
		local classes = if Boolean.toJSBoolean(RegExp("cancel|phase"):test(label))
			then { "svg-align" }
			else {}
		vlist = buildCommon:makeVList({
			positionType = "individualShift",
			children = {
				-- Write the \cancel stroke on top of inner.
				{ type = "elem", elem = inner, shift = 0 },
				{ type = "elem", elem = img, shift = imgShift, wrapperClasses = classes },
			},
		}, options)
	end
	if Boolean.toJSBoolean(RegExp("cancel"):test(label)) then
		-- The cancel package documentation says that cancel lines add their height
		-- to the expression, but tests show that isn't how it actually works.
		vlist.height = inner.height
		vlist.depth = inner.depth
	end
	if
		Boolean.toJSBoolean((function()
			local ref = RegExp("cancel"):test(label)
			return if Boolean.toJSBoolean(ref) then not Boolean.toJSBoolean(isSingleChar) else ref
		end)())
	then
		-- cancel does not create horiz space for its line extension.
		return buildCommon:makeSpan({ "mord", "cancel-lap" }, { vlist }, options)
	else
		return buildCommon:makeSpan({ "mord" }, { vlist }, options)
	end
end
local function mathmlBuilder(group, options)
	local fboxsep = 0
	local node = mathMLTree.MathNode.new(
		if Array.indexOf(group.label, "colorbox") --[[ ROBLOX CHECK: check if 'group.label' is an Array ]]
				> -1 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			then "mpadded"
			else "menclose",
		{ mml:buildGroup(group.body, options) }
	)
	local condition_ = group.label
	if condition_ == "\\cancel" then
		node:setAttribute("notation", "updiagonalstrike")
	elseif condition_ == "\\bcancel" then
		node:setAttribute("notation", "downdiagonalstrike")
	elseif condition_ == "\\phase" then
		node:setAttribute("notation", "phasorangle")
	elseif condition_ == "\\sout" then
		node:setAttribute("notation", "horizontalstrike")
	elseif condition_ == "\\fbox" then
		node:setAttribute("notation", "box")
	elseif condition_ == "\\angl" then
		node:setAttribute("notation", "actuarial")
	elseif condition_ == "\\fcolorbox" or condition_ == "\\colorbox" then
		-- <menclose> doesn't have a good notation option. So use <mpadded>
		-- instead. Set some attributes that come included with <menclose>.
		fboxsep = options:fontMetrics().fboxsep * options:fontMetrics().ptPerEm
		node:setAttribute("width", ("+%spt"):format(tostring(2 * fboxsep)))
		node:setAttribute("height", ("+%spt"):format(tostring(2 * fboxsep)))
		node:setAttribute("lspace", ("%spt"):format(tostring(fboxsep))) --
		node:setAttribute("voffset", ("%spt"):format(tostring(fboxsep)))
		if group.label == "\\fcolorbox" then
			local thk = math.max(
				options:fontMetrics().fboxrule, -- default
				options.minRuleThickness -- user override
			)
			node:setAttribute(
				"style",
				"border: " .. tostring(thk) .. "em solid " .. tostring(String(group.borderColor))
			)
		end
	elseif condition_ == "\\xcancel" then
		node:setAttribute("notation", "updiagonalstrike downdiagonalstrike")
	end
	if Boolean.toJSBoolean(group.backgroundColor) then
		node:setAttribute("mathbackground", group.backgroundColor)
	end
	return node
end
defineFunction({
	type = "enclose",
	names = { "\\colorbox" },
	props = { numArgs = 2, allowedInText = true, argTypes = { "color", "text" } },
	handler = function(self, ref0, args, optArgs)
		local parser, funcName = ref0.parser, ref0.funcName
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
			type = "enclose",
			mode = parser.mode,
			label = funcName,
			backgroundColor = color,
			body = body,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineFunction({
	type = "enclose",
	names = { "\\fcolorbox" },
	props = { numArgs = 3, allowedInText = true, argTypes = { "color", "color", "text" } },
	handler = function(self, ref0, args, optArgs)
		local parser, funcName = ref0.parser, ref0.funcName
		local borderColor = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"color-token"
		).color
		local backgroundColor = assertNodeType(
			args[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"color-token"
		).color
		local body = args[
			3 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return {
			type = "enclose",
			mode = parser.mode,
			label = funcName,
			backgroundColor = backgroundColor,
			borderColor = borderColor,
			body = body,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineFunction({
	type = "enclose",
	names = { "\\fbox" },
	props = { numArgs = 1, argTypes = { "hbox" }, allowedInText = true },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		return {
			type = "enclose",
			mode = parser.mode,
			label = "\\fbox",
			body = args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}
	end,
})
defineFunction({
	type = "enclose",
	names = { "\\cancel", "\\bcancel", "\\xcancel", "\\sout", "\\phase" },
	props = { numArgs = 1 },
	handler = function(self, ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return { type = "enclose", mode = parser.mode, label = funcName, body = body }
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineFunction({
	type = "enclose",
	names = { "\\angl" },
	props = { numArgs = 1, argTypes = { "hbox" }, allowedInText = false },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		return {
			type = "enclose",
			mode = parser.mode,
			label = "\\angl",
			body = args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}
	end,
})
