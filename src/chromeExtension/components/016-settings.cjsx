_                 = require '../../vendor/lodash'
timm              = require 'timm'
React             = require 'react'
ReactRedux        = require 'react-redux'
{
  Icon,
  Modal,
  Checkbox, TextInput, NumberInput, ColorInput,
  Button,
  isDark,
}                 = require 'giu'
Promise           = require 'bluebird'
Login             = require './010-login'
actions           = require '../actions/actions'
DEFAULT_SETTINGS  = require('../reducers/settingsReducer').DEFAULT_SETTINGS

FORM_KEYS = [
  'fShowClosedActions',
  'fShorthandForDuplicates',
  'fCollapseAllNewStories',
  'fExpandAllNewAttachments',
  'fDiscardRemoteClientLogs',
  'serverFilter', 'localClientFilter',
  'maxRecords', 'forgetHysteresis',
  'colorClientBg', 'colorServerBg', 'colorUiBg',
]

idxPresetColors = 2  # next one will be dark!
PRESET_COLORS = [
  { colorClientBg: 'aliceblue', colorServerBg: 'rgb(214, 236, 255)', colorUiBg: 'white'},
  { colorClientBg: 'rgb(255, 240, 240)', colorServerBg: 'rgb(255, 214, 215)', colorUiBg: 'white'},
  { colorClientBg: 'rgb(250, 240, 255)', colorServerBg: 'rgb(238, 214, 255)', colorUiBg: 'white'},
  { colorClientBg: 'rgb(17, 22, 54)', colorServerBg: 'rgb(14, 11, 33)', colorUiBg: 'black'},
]

mapStateToProps = (state) ->
  settings:       state.settings
  serverFilter:   state.cx.serverFilter
  localClientFilter: state.cx.localClientFilter

Settings = React.createClass
  displayName: 'Settings'

  #-----------------------------------------------------
  propTypes:
    onClose:                    React.PropTypes.func.isRequired
    colors:                     React.PropTypes.object.isRequired
    # From Redux.connect
    settings:                   React.PropTypes.object.isRequired
    serverFilter:               React.PropTypes.string
    localClientFilter:          React.PropTypes.string
    updateSettings:             React.PropTypes.func.isRequired
    setServerFilter:            React.PropTypes.func.isRequired
    setLocalClientFilter:       React.PropTypes.func.isRequired
  getInitialState: -> timm.merge {}, @props.settings,
    _fCanSave: true
    # maxRecords: @props.settings.maxRecords
    # forgetHysteresis: @props.settings.forgetHysteresis
    cmdsToInputs: null

  componentDidMount: -> @checkLocalStorage()
  componentWillReceiveProps: (nextProps) ->
    { maxRecords, forgetHysteresis } = nextProps.settings;
    @setState({ maxRecords, forgetHysteresis })

  #-----------------------------------------------------
  render: ->
    {colors} = @props
    buttons = [
      {label: 'Cancel', onClick: @props.onClose, left: true}
      {label: 'Reset defaults', onClick: @onReset, left: true}
      {label: 'Save', onClick: @onSubmit, defaultButton: true, style: _style.modalDefaultButton(colors)}
    ]
    {cmdsToInputs} = @state
    <Modal
      buttons={buttons}
      onEsc={@props.onClose}
      style={_style.modal colors}
    >
      {@renderLocalStorageWarning()}
      <Checkbox ref="fShowClosedActions"
        label={<span>Show <i>CLOSED</i> actions</span>}
        value={@state.fShowClosedActions}
        cmds={cmdsToInputs}
      /><br />
      <Checkbox ref="fShorthandForDuplicates"
        label={
          <span>
            Use shorthand notation for identical consecutive logs ( <Icon icon="copy" style={_style.icon} disabled /> )
          </span>
        }
        value={@state.fShorthandForDuplicates}
        cmds={cmdsToInputs}
      /><br />
      <Checkbox ref="fCollapseAllNewStories"
        label="Collapse all new stories (even if they are still open)"
        value={@state.fCollapseAllNewStories}
        cmds={cmdsToInputs}
      /><br />
      <Checkbox ref="fExpandAllNewAttachments"
        label="Expand all attachments upon receipt"
        value={@state.fExpandAllNewAttachments}
        cmds={cmdsToInputs}
      /><br />
      <Checkbox ref="fDiscardRemoteClientLogs"
        label="Discard stories from remote clients upon receipt"
        value={@state.fDiscardRemoteClientLogs}
        cmds={cmdsToInputs}
      /><br />
      <br />
      {@renderLogFilters()}
      {@renderForgetSettings()}
      {@renderColors()}
      {@renderVersion()}
    </Modal>

  renderLogFilters: ->
    {cmdsToInputs} = @state
    return [
      <div key="filterTitle" style={{marginBottom: 5}}>
        Log filters, e.g. <b>foo, ba*:INFO, -test, *:WARN</b>{' '}
        <a href="https://github.com/guigrpa/storyboard#log-filtering" target="_blank" style={_style.link}>
          (more examples here)
        </a>:
      </div>
    ,
      <ul key="filterList" style={_style.filters.list}>
        <li>
          <label htmlFor="serverFilter" style={_style.filters.itemLabel}>
            Server:
          </label>{' '}
          <TextInput ref="serverFilter"
            id="serverFilter"
            value={@props.serverFilter}
            required errorZ={52}
            style={_style.textNumberInput 300}
            cmds={cmdsToInputs}
          />
        </li>
        <li>
          <label htmlFor="localClientFilter" style={_style.filters.itemLabel}>
            Local client:
          </label>{' '}
          <TextInput ref="localClientFilter"
            id="localClientFilter"
            value={@props.localClientFilter}
            required errorZ={52}
            style={_style.textNumberInput 300}
            cmds={cmdsToInputs}
          />
        </li>
      </ul>
    ]

  # For maxRecords and forgetHysteresis, we keep track of their current values
  # to update the tooltip accordingly
  renderForgetSettings: ->
    {cmdsToInputs} = @state
    <div>
      <label htmlFor="maxRecords">
        Number of logs and stories to remember:
      </label>{' '}
      <NumberInput ref="maxRecords"
        id="maxRecords"
        step={1} min={0}
        value={@state.maxRecords}
        onChange={(ev, maxRecords) => @setState({ maxRecords })}
        style={_style.textNumberInput 50}
        required errorZ={52}
        cmds={cmdsToInputs}
      />{' '}
      <label htmlFor="forgetHysteresis">
        with hysteresis:
      </label>{' '}
      <NumberInput ref="forgetHysteresis"
        id="forgetHysteresis"
        step={.05} min={0} max={1}
        value={@state.forgetHysteresis}
        onChange={(ev, forgetHysteresis) => @setState({ forgetHysteresis })}
        style={_style.textNumberInput 50}
        required errorZ={52}
        cmds={cmdsToInputs}
      />{' '}
      <Icon
        icon="info-circle"
        title={@maxLogsDesc()}
        style={_style.maxLogsDesc}
      />
    </div>

  renderColors: ->
    {cmdsToInputs} = @state
    <div>
      Colors:
      client stories:
      {' '}
      <ColorInput ref="colorClientBg"
        id="colorClientBg"
        value={@state.colorClientBg}
        floatZ={52}
        styleOuter={_style.colorInput}
        cmds={cmdsToInputs}
      />
      {' '}
      server stories:
      {' '}
      <ColorInput ref="colorServerBg"
        id="colorServerBg"
        value={@state.colorServerBg}
        floatZ={52}
        styleOuter={_style.colorInput}
        cmds={cmdsToInputs}
      />
      {' '}
      background:
      {' '}
      <ColorInput ref="colorUiBg"
        id="colorUiBg"
        value={@state.colorUiBg}
        floatZ={52}
        styleOuter={_style.colorInput}
        cmds={cmdsToInputs}
      />
      <div style={{marginTop: 3}}>
        (Use very light or very dark colors for best results, or choose a
        {' '}
        <Button onClick={@onClickPresetColors}>preset</Button>)
      </div>
    </div>

  renderVersion: ->
    return if not process.env.STORYBOARD_VERSION
    <div style={_style.version}>
      Storyboard DevTools v{process.env.STORYBOARD_VERSION}<br/>
      (c) <a href="https://github.com/guigrpa" target="_blank" style={_style.link}>Guillermo Grau</a> 2016
    </div>

  renderLocalStorageWarning: ->
    return if @state._fCanSave
    <div className="allowUserSelect" style={_style.localStorageWarning}>
      Changes to these settings can't be saved (beyond your current session)
      due to your current Chrome configuration. Please visit
      <b>chrome://settings/content</b> and
      uncheck the option "Block third-party cookies and site
      data". Then close the Chrome DevTools and open them again.
    </div>

  maxLogsDesc: ->
    hyst = @state.forgetHysteresis
    hi = @state.maxRecords
    lo = hi - hi * hyst
    return "When the backlog reaches #{hi}, Storyboard will " +
      "start forgetting old stuff until it goes below #{lo}"

  #-----------------------------------------------------
  onSubmit: ->
    settings = {}
    Promise.map FORM_KEYS, (key) =>
      ref = this.refs[key]
      if not(ref) then throw new Error('Could not read form')
      this.refs[key].validateAndGetValue()
      .then (val) -> settings[key] = val
    .then =>
      persistedSettings = timm.omit(settings, ['serverFilter', 'localClientFilter'])
      @props.updateSettings persistedSettings
      if settings.serverFilter isnt @props.serverFilter
        @props.setServerFilter settings.serverFilter
      if settings.localClientFilter isnt @props.localClientFilter
        @props.setLocalClientFilter settings.localClientFilter
      @props.onClose()
    return

  # Reset to factory settings, and send a `REVERT` command to all inputs
  onReset: ->
    @setState DEFAULT_SETTINGS
    @setState cmdsToInputs: [{ type: 'REVERT' }]
    return

  onClickPresetColors: ->
    idxPresetColors = (idxPresetColors + 1) % PRESET_COLORS.length
    presetColors = PRESET_COLORS[idxPresetColors]
    @setState presetColors
    return

  #-----------------------------------------------------
  checkLocalStorage: ->
    try
      ls = localStorage.foo
      @setState _fCanSave: true
    catch e
      @setState _fCanSave: false

#-----------------------------------------------------
_style =
  modal: (colors) ->
    backgroundColor: if colors.colorUiBgIsDark then 'black' else 'white'
    color: if colors.colorUiBgIsDark then 'white' else 'black'
  modalDefaultButton: (colors) ->
    border: if colors.colorUiBgIsDark then '1px solid white' else undefined
  version:
    textAlign: 'right'
    color: '#888'
    marginTop: 8
    marginBottom: 8
  link:
    color: 'currentColor'
  icon:
    color: 'currentColor'
  localStorageWarning:
    color: 'red'
    border: "1px solid red"
    padding: 15
    marginBottom: 10
    borderRadius: 2
  maxLogsDesc:
    cursor: 'pointer'
  filters:
    list:
      marginTop: 0
    itemLabel:
      display: 'inline-block'
      width: 80
  colorInput:
    position: 'relative'
    top: 1
  textNumberInput: (width) ->
    backgroundColor: 'transparent'
    width: width

#-----------------------------------------------------
connect = ReactRedux.connect mapStateToProps, actions
module.exports = connect Settings
