_                 = require '../../vendor/lodash'
React             = require 'react'
ReactRedux        = require 'react-redux'
PureRenderMixin   = require 'react-addons-pure-render-mixin'
timm              = require 'timm'
tinycolor         = require 'tinycolor2'
moment            = require 'moment'
chalk             = require 'chalk'
{ Icon, Spinner, isDark } = require 'giu'
ColoredText       = require './030-coloredText'
actions           = require '../actions/actions'
ansiColors        = require '../../gral/ansiColors'
treeLines         = require '../../gral/treeLines'
{ deserialize }   = require '../../gral/serialize'
k                 = require '../../gral/constants'

_quickFind = (msg, quickFind) ->
  return msg if not quickFind.length
  re = new RegExp quickFind, 'gi'
  msg = msg.replace re, chalk.bgYellow("$1")
  msg

#-====================================================
# ## Story
#-====================================================
mapStateToProps = (state) ->
  timeType:           state.settings.timeType
  fShowClosedActions: state.settings.fShowClosedActions
  quickFind:          state.stories.quickFind
mapDispatchToProps = (dispatch) ->
  setTimeType: (timeType) -> dispatch actions.setTimeType timeType
  onToggleExpanded: (pathStr) -> dispatch actions.toggleExpanded pathStr
  onToggleHierarchical: (pathStr) -> dispatch actions.toggleHierarchical pathStr
  onToggleAttachment: (pathStr, recordId) ->
    dispatch actions.toggleAttachment pathStr, recordId

_Story = React.createClass
  displayName: 'Story'

  #-----------------------------------------------------
  propTypes:
    story:                  React.PropTypes.object.isRequired
    level:                  React.PropTypes.number.isRequired
    seqFullRefresh:         React.PropTypes.number.isRequired
    colors:                 React.PropTypes.object.isRequired
    # From Redux.connect
    timeType:               React.PropTypes.string.isRequired
    fShowClosedActions:     React.PropTypes.bool.isRequired
    quickFind:              React.PropTypes.string.isRequired
    setTimeType:            React.PropTypes.func.isRequired
    onToggleExpanded:       React.PropTypes.func.isRequired
    onToggleHierarchical:   React.PropTypes.func.isRequired
    onToggleAttachment:     React.PropTypes.func.isRequired

  #-----------------------------------------------------
  render: ->
    if @props.story.fWrapper
      return <div>{@renderRecords()}</div>
    if @props.level is 1 then return @renderRootStory()
    return @renderNormalStory()

  renderRootStory: ->
    {level, story, colors} = @props
    <div className="rootStory" style={_style.outer level, story, colors}>
      <MainStoryTitle
        title={story.title}
        numRecords={story.numRecords}
        fHierarchical={story.fHierarchical}
        fExpanded={story.fExpanded}
        onToggleExpanded={@toggleExpanded}
        onToggleHierarchical={@toggleHierarchical}
      />
      {@renderRecords()}
    </div>

  renderNormalStory: ->
    {level, story, colors} = @props
    {title, fOpen} = story
    <div className="story" style={_style.outer(level, story, colors)}>
      <Line
        record={story}
        level={@props.level}
        fDirectChild={false}
        timeType={@props.timeType}
        setTimeType={@props.setTimeType}
        quickFind={@props.quickFind}
        onToggleExpanded={@toggleExpanded}
        onToggleHierarchical={@toggleHierarchical}
        seqFullRefresh={@props.seqFullRefresh}
        colors={colors}
      />
      {@renderRecords()}
    </div>

  renderRecords: ->
    return if not @props.story.fExpanded
    records = @prepareRecords @props.story.records
    out = []
    for record in records
      el = @renderRecord record
      continue if not el?
      out.push el
      if record.objExpanded and record.obj?
        out = out.concat @renderAttachment record
      if record.repetitions
        out.push @renderRepetitions record
    out

  renderRecord: (record) ->
    {id, fStoryObject, storyId, obj, objExpanded, action} = record
    fDirectChild = storyId is @props.story.storyId
    if fStoryObject
      return <Story key={storyId}
        story={record}
        level={@props.level + 1}
        seqFullRefresh={@props.seqFullRefresh}
        colors={@props.colors}
      />
    else
      if fDirectChild
        return if action is 'CREATED'
        return if (not @props.fShowClosedActions) and (action is 'CLOSED')
      return <Line key={"#{storyId}_#{id}"}
        record={record}
        level={@props.level}
        fDirectChild={fDirectChild}
        timeType={@props.timeType}
        setTimeType={@props.setTimeType}
        quickFind={@props.quickFind}
        onToggleAttachment={@toggleAttachment}
        seqFullRefresh={@props.seqFullRefresh}
        colors={@props.colors}
      />
    out

  renderAttachment: (record) ->
    {storyId, id, obj, objOptions, version} = record
    props = _.pick @props, ['level', 'timeType', 'setTimeType', 'quickFind', 'seqFullRefresh', 'colors']
    lines = if version >= 2 then treeLines(deserialize(obj), objOptions) else obj
    return lines.map (line, idx) ->
      <AttachmentLine key={"#{storyId}_#{id}_#{idx}"}
        record={record}
        {...props}
        msg={line}
      />

  renderRepetitions: (record) ->
    {storyId, id} = record
    props = _.pick @props, ['level', 'timeType', 'setTimeType', 'quickFind', 'seqFullRefresh', 'colors']
    <RepetitionLine key={"#{storyId}_#{id}_repetitions"}
      record={record}
      {...props}
    />

  #-----------------------------------------------------
  toggleExpanded: -> @props.onToggleExpanded @props.story.pathStr
  toggleHierarchical: -> @props.onToggleHierarchical @props.story.pathStr
  toggleAttachment: (recordId) ->
    @props.onToggleAttachment @props.story.pathStr, recordId

  #-----------------------------------------------------
  prepareRecords: (records) ->
    if @props.story.fHierarchical
      out = _.sortBy records, 't'
    else
      out = @flatten records
    out

  flatten: (records, level = 0) ->
    out = []
    for record in records
      if record.fStoryObject
        out = out.concat @flatten(record.records, level + 1)
      else
        out.push record
    if level is 0
      out = _.sortBy out, 't'
    out

#-----------------------------------------------------
_style =
  outer: (level, story, colors) ->
    backgroundColor: if story.fServer then colors.colorServerBg else colors.colorClientBg
    color: if story.fServer then colors.colorServerFg else colors.colorClientFg
    marginBottom: if level <= 1 then 10
    padding: if level <= 1 then 2

#-----------------------------------------------------
connect = ReactRedux.connect mapStateToProps, mapDispatchToProps
Story = connect _Story


#-====================================================
# ## MainStoryTitle
#-====================================================
MainStoryTitle = React.createClass
  displayName: 'MainStoryTitle'
  mixins: [PureRenderMixin]

  #-----------------------------------------------------
  propTypes:
    title:                  React.PropTypes.string.isRequired
    numRecords:             React.PropTypes.number.isRequired
    fHierarchical:          React.PropTypes.bool.isRequired
    fExpanded:              React.PropTypes.bool.isRequired
    onToggleExpanded:       React.PropTypes.func.isRequired
    onToggleHierarchical:   React.PropTypes.func.isRequired
  getInitialState: ->
    fHovered:               false

  #-----------------------------------------------------
  render: ->
    <div
      className="rootStoryTitle"
      style={_styleMainTitle.outer}
      onMouseEnter={@onMouseEnter}
      onMouseLeave={@onMouseLeave}
    >
      {@renderCaret()}
      <span
        style={_styleMainTitle.title}
        onClick={@props.onToggleExpanded}
      >
        {@props.title.toUpperCase()}{' '}
        <span style={_styleMainTitle.numRecords}>[{@props.numRecords}]</span>
      </span>
      {@renderToggleHierarchical()}
    </div>

  renderCaret: ->
    return if not @state.fHovered
    icon = if @props.fExpanded then 'caret-down' else 'caret-right'
    <span
      onClick={@props.onToggleExpanded}
      style={_styleMainTitle.caret.outer}
    >
      <Icon icon={icon} style={_styleMainTitle.caret.icon}/>
    </span>

  renderToggleHierarchical: ->
    return if not @state.fHovered
    <HierarchicalToggle
      fHierarchical={@props.fHierarchical}
      onToggleHierarchical={@props.onToggleHierarchical}
      fFloat
    />

  #-----------------------------------------------------
  onMouseEnter: -> @setState {fHovered: true}
  onMouseLeave: -> @setState {fHovered: false}

#-----------------------------------------------------
_styleMainTitle =
  outer:
    textAlign: 'center'
    marginBottom: 5
    cursor: 'pointer'
  title:
    fontWeight: 900
    letterSpacing: 3
  numRecords:
    color: 'darkgrey'
  caret:
    outer:
      display: 'inline-block'
      position: 'absolute'
    icon:
      display: 'inline-block'
      position: 'absolute'
      right: 6
      top: 2

#-====================================================
# ## AttachmentLine
#-====================================================
AttachmentLine = React.createClass
  displayName: 'AttachmentLine'
  mixins: [PureRenderMixin]

  #-----------------------------------------------------
  propTypes:
    record:                 React.PropTypes.object.isRequired
    level:                  React.PropTypes.number.isRequired
    timeType:               React.PropTypes.string.isRequired
    setTimeType:            React.PropTypes.func.isRequired
    seqFullRefresh:         React.PropTypes.number.isRequired
    msg:                    React.PropTypes.string.isRequired
    quickFind:              React.PropTypes.string.isRequired
    colors:                 React.PropTypes.object.isRequired

  #-----------------------------------------------------
  render: ->
    {record, msg, colors} = @props
    style = _styleLine.log record, colors
    msg = _quickFind msg, @props.quickFind
    <div
      className="attachmentLine allowUserSelect"
      style={style}
    >
      <Time
        fShowFull={false}
        timeType={@props.timeType}
        setTimeType={@props.setTimeType}
        seqFullRefresh={@props.seqFullRefresh}
      />
      <Src src={record.src}/>
      <Severity level={record.objLevel}/>
      <Indent level={@props.level}/>
      <CaretOrSpace/>
      <ColoredText text={'  ' + msg}/>
    </div>


#-====================================================
# ## RepetitionLine
#-====================================================
RepetitionLine = React.createClass
  displayName: 'RepetitionLine'
  mixins: [PureRenderMixin]

  #-----------------------------------------------------
  propTypes:
    record:                 React.PropTypes.object.isRequired
    level:                  React.PropTypes.number.isRequired
    timeType:               React.PropTypes.string.isRequired
    setTimeType:            React.PropTypes.func.isRequired
    seqFullRefresh:         React.PropTypes.number.isRequired
    quickFind:              React.PropTypes.string.isRequired
    colors:                 React.PropTypes.object.isRequired

  #-----------------------------------------------------
  render: ->
    {record, level, timeType, setTimeType, seqFullRefresh, colors} = @props
    style = _styleLine.log record, colors
    msg = " x#{record.repetitions+1}, latest: "
    msg = _quickFind msg, @props.quickFind
    <div
      className="attachmentLine allowUserSelect"
      style={style}
    >
      <Time
        fShowFull={false}
        timeType={timeType}
        setTimeType={setTimeType}
        seqFullRefresh={seqFullRefresh}
      />
      <Src/>
      <Severity/>
      <Indent level={level}/>
      <CaretOrSpace/>
      <Icon icon="copy" disabled style={{color: 'currentColor'}}/>
      <ColoredText text={msg}/>
      <Time
        t={record.tLastRepetition}
        fTrim
        timeType={timeType}
        setTimeType={setTimeType}
        seqFullRefresh={seqFullRefresh}
      />
    </div>


#-====================================================
# ## Line
#-====================================================
Line = React.createClass
  displayName: 'Line'
  mixins: [PureRenderMixin]

  #-----------------------------------------------------
  propTypes:
    record:                 React.PropTypes.object.isRequired
    level:                  React.PropTypes.number.isRequired
    fDirectChild:           React.PropTypes.bool.isRequired
    timeType:               React.PropTypes.string.isRequired
    setTimeType:            React.PropTypes.func.isRequired
    quickFind:              React.PropTypes.string.isRequired
    onToggleExpanded:       React.PropTypes.func
    onToggleHierarchical:   React.PropTypes.func
    onToggleAttachment:     React.PropTypes.func
    seqFullRefresh:         React.PropTypes.number.isRequired
    colors:                 React.PropTypes.object.isRequired
  getInitialState: ->
    fHovered:               false

  #-----------------------------------------------------
  render: ->
    {record, fDirectChild, level, colors} = @props
    {id, msg, fStory, fStoryObject, fServer, fOpen, title, action} = record
    if fStoryObject then msg = title
    if fStory
      msg = if not fDirectChild then "#{title} " else ''
      if action then msg += chalk.gray "[#{action}]"
    if fStoryObject
      className = 'storyTitle'
      style = _styleLine.titleRow level
      indentLevel = level - 1
      if fOpen then spinner = <Spinner style={_styleLine.spinner}/>
    else
      className = 'log'
      style = _styleLine.log record, colors
      indentLevel = level
    className += ' allowUserSelect'
    # No animation on dark backgrounds to prevent antialiasing defects
    fDarkBg = if fServer then colors.colorServerBgIsDark else colors.colorClientBgIsDark
    if (not fDarkBg) then className += ' fadeIn'
    <div
      className={className}
      onMouseEnter={@onMouseEnter}
      onMouseLeave={@onMouseLeave}
      style={style}
    >
      {@renderTime record}
      <Src src={record.src} colors={colors}/>
      <Severity level={record.level} colors={colors}/>
      <Indent level={indentLevel}/>
      {@renderCaretOrSpace record}
      {@renderMsg fStoryObject, msg, record.level}
      {@renderWarningIcon record}
      {if fStoryObject then @renderToggleHierarchical record}
      {spinner}
      {@renderAttachmentIcon record}
    </div>

  renderMsg: (fStoryObject, msg, level) ->
    msg = _quickFind msg, @props.quickFind
    if level >= k.LEVEL_STR_TO_NUM.ERROR then msg = chalk.red.bold msg
    else if level >= k.LEVEL_STR_TO_NUM.WARN then msg = chalk.red.yellow msg
    if fStoryObject
      <ColoredText
        text={msg}
        onClick={@props.onToggleExpanded}
        style={_styleLine.title}
      />
    else
      <ColoredText text={msg}/>

  renderTime: (record) ->
    {fStoryObject, t} = record
    {level, timeType, setTimeType, seqFullRefresh} = @props
    fShowFull = (fStoryObject and level <= 2) or (level <= 1)
    <Time
      t={t}
      fShowFull={fShowFull}
      timeType={timeType}
      setTimeType={setTimeType}
      seqFullRefresh={seqFullRefresh}
    />

  renderCaretOrSpace: (record) ->
    if @props.onToggleExpanded and record.fStoryObject
      fExpanded = record.fExpanded
    <CaretOrSpace fExpanded={fExpanded} onToggleExpanded={@props.onToggleExpanded}/>

  renderToggleHierarchical: (story) ->
    return if not @props.onToggleHierarchical
    return if not @state.fHovered
    <HierarchicalToggle
      fHierarchical={story.fHierarchical}
      onToggleHierarchical={@props.onToggleHierarchical}
    />

  renderWarningIcon: (record) ->
    return if record.fExpanded
    { fHasWarning, fHasError } = record
    return if not(fHasWarning or fHasError)
    title = "Story contains #{if fHasError then 'an error' else 'a warning'}"
    <Icon
      icon="warning"
      title={title}
      onClick={@props.onToggleExpanded}
      style={_styleLine.warningIcon(if fHasError then 'error' else 'warning')}
    />

  renderAttachmentIcon: (record) ->
    return if not record.obj?
    if record.objIsError
      icon = if record.objExpanded then 'folder-open' else 'folder'
      style = timm.set _styleLine.attachmentIcon, 'color', '#cc0000'
    else
      icon = if record.objExpanded then 'folder-open-o' else 'folder-o'
      style = _styleLine.attachmentIcon
    <Icon
      icon={icon}
      onClick={@onClickAttachment}
      style={style}
    />

  #-----------------------------------------------------
  onMouseEnter: -> @setState {fHovered: true}
  onMouseLeave: -> @setState {fHovered: false}
  onClickAttachment: -> @props.onToggleAttachment @props.record.id

#-----------------------------------------------------
_styleLine =
  titleRow: (level) ->
    fontWeight: 900
    fontFamily: 'Menlo, Consolas, monospace'
    whiteSpace: 'pre'
    overflowX: 'hidden'
    textOverflow: 'ellipsis'
  title:
    cursor: 'pointer'
  log: (record, colors) ->
    {fServer} = record
    backgroundColor: if fServer then colors.colorServerBg else colors.colorClientBg
    color: if fServer then colors.colorServerFg else colors.colorClientFg
    fontFamily: 'Menlo, Consolas, monospace'
    whiteSpace: 'pre'
    fontWeight: if record.fStory and (record.action is 'CREATED') then 900
    overflowX: 'hidden'
    textOverflow: 'ellipsis'
  spinner:
    marginLeft: 8
    overflow: 'hidden'
  attachmentIcon:
    marginLeft: 8
    cursor: 'pointer'
    display: 'inline'
  warningIcon: (type) ->
    marginLeft: 8
    color: if type is 'warning' then '#ff6600' else '#cc0000'
    display: 'inline'

#-====================================================
# ## Time
#-====================================================
TIME_LENGTH = 25

Time = React.createClass
  displayName: 'Time'
  mixins: [PureRenderMixin]
  propTypes:
    t:                      React.PropTypes.number
    fShowFull:              React.PropTypes.bool
    timeType:               React.PropTypes.string.isRequired
    setTimeType:            React.PropTypes.func.isRequired
    seqFullRefresh:         React.PropTypes.number.isRequired
    fTrim:                  React.PropTypes.bool

  render: ->
    {t, fShowFull, timeType, fTrim} = @props
    if not t? then return <span>{_.padEnd '', TIME_LENGTH}</span>
    fRelativeTime = false
    m = moment t
    localTime = m.format('YYYY-MM-DD HH:mm:ss.SSS')
    if timeType is 'RELATIVE'
      shownTime = m.fromNow()
      fRelativeTime = true
    else
      if timeType is 'UTC' then m.utc()
      if fShowFull
        shownTime = m.format('YYYY-MM-DD HH:mm:ss.SSS')
      else
        shownTime = '           ' + m.format('HH:mm:ss.SSS')
      if timeType is 'UTC' then shownTime += 'Z'
    shownTime = _.padEnd shownTime, TIME_LENGTH
    if fTrim then shownTime = shownTime.trim()
    <span
      onClick={@onClick}
      style={_styleTime fRelativeTime}
      title={if timeType isnt 'LOCAL' then localTime}
    >
      {shownTime}
    </span>

  onClick: ->
    newTimeType = switch @props.timeType
      when 'LOCAL' then 'RELATIVE'
      when 'RELATIVE' then 'UTC'
      else 'LOCAL'
    @props.setTimeType newTimeType

_styleTime = (fRelativeTime) ->
  display: 'inline'
  cursor: 'pointer'
  fontStyle: if fRelativeTime then 'italic'

#-====================================================
# ## Severity
#-====================================================
Severity = React.createClass
  displayName: 'Severity'
  mixins: [PureRenderMixin]
  propTypes:
    level:                  React.PropTypes.number
  render: ->
    {level} = @props
    if level?
      levelStr = ansiColors.LEVEL_NUM_TO_COLORED_STR[level]
      return <ColoredText text={levelStr}/>
    else
      return <span>      </span>

#-====================================================
# ## Src
#-====================================================
Src = React.createClass
  displayName: 'Src'
  mixins: [PureRenderMixin]
  propTypes:
    src:                    React.PropTypes.string
  render: ->
    {src} = @props
    if src?
      srcStr = ansiColors.getSrcChalkColor(src) _.padStart(src + ' ', 20)
      return <ColoredText text={srcStr}/>
    else
      return <span>{_.repeat(' ', 20)}</span>

#-====================================================
# ## Indent
#-====================================================
Indent = ({level}) ->
  style =
    display: 'inline-block'
    width: 20 * (level - 1)
  <div style={style}/>

#-====================================================
# ## CaretOrSpace
#-====================================================
CaretOrSpace = React.createClass
  displayName: 'CaretOrSpace'
  mixins: [PureRenderMixin]
  propTypes:
    fExpanded:              React.PropTypes.bool
    onToggleExpanded:       React.PropTypes.func
  render: ->
    if @props.fExpanded?
      iconType = if @props.fExpanded then 'caret-down' else 'caret-right'
      icon = <Icon icon={iconType} onClick={@props.onToggleExpanded}/>
    <span style={_styleCaretOrSpace}>{icon}</span>

_styleCaretOrSpace =
  display: 'inline-block'
  width: 30
  paddingLeft: 10
  cursor: 'pointer'


#-====================================================
# ## HierarchicalToggle
#-====================================================
HierarchicalToggle = React.createClass
  displayName: 'HierarchicalToggle'
  mixins: [PureRenderMixin]
  propTypes:
    fHierarchical:          React.PropTypes.bool.isRequired
    onToggleHierarchical:   React.PropTypes.func.isRequired
    fFloat:                 React.PropTypes.bool
  render: ->
    if @props.fHierarchical
      text = 'Show flat'
      icon = 'bars'
    else
      text = 'Show tree'
      icon = 'sitemap'
    <span
      onClick={@props.onToggleHierarchical}
      style={_styleHierarchical.outer @props.fFloat}
    >
      <Icon icon={icon} style={_styleHierarchical.icon}/>
      {text}
    </span>

_styleHierarchical =
  outer: (fFloat) ->
    position: if fFloat then 'absolute'
    marginLeft: 10
    color: 'darkgrey'
    textDecoration: 'underline'
    cursor: 'pointer'
    fontWeight: 'normal'
    fontFamily: 'Menlo, Consolas, monospace'
  icon:
    marginRight: 4

#-----------------------------------------------------
module.exports = Story
