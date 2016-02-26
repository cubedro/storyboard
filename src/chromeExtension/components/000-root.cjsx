_                 = require '../../vendor/lodash'
React             = require 'react'
Login             = require './010-login'
LargeMessage      = require './900-largeMessage'
ansiColors        = require '../../gral/ansiColors'

require './app.sass'

Root = React.createClass
  displayName: 'Root'

  #-----------------------------------------------------
  propTypes:
    msgSubscribe:           React.PropTypes.func.isRequired
    msgSend:                React.PropTypes.func.isRequired
  getInitialState: ->
    rootStory:              []
    fEstablishedE2E:        false
    fWarnEstablishmentE2E:  false
    loginStatus:            'LOGGED_OUT'
    fLoginRequired:         false

  #-----------------------------------------------------
  componentDidMount: -> 
    @props.msgSubscribe @_rxMsg
    @_txMsg 'CONNECT_REQUEST'
    setTimeout =>
      if not @state.fEstablishedE2E
        @setState {fWarnEstablishmentE2E: true}
    , 2000

  #-----------------------------------------------------
  render: -> <div style={_style.outer}>{@_renderContents()}</div>

  _renderContents: ->
    if not @state.fEstablishedE2E then return @_renderConnecting()
    <div>
      <Login 
        fLoginRequired={@state.fLoginRequired}
        loginStatus={@state.loginStatus}
        submit={@_handleSubmitLogin}
      />
      {@_renderDownloadBuffered()}
      <div>Records:</div>
      <ul>
        {@state.rootStory.map @_renderRecord}
      </ul>
    </div>

  _renderConnecting: ->
    <LargeMessage>
      Connecting to Storyboard...
      {@_renderConnecting2()}
    </LargeMessage>

  _renderConnecting2: ->
    return if not @state.fWarnEstablishmentE2E 
    <div>If this seems to be taking a long time, please verify your URL</div>

  _renderDownloadBuffered: ->
    <button onClick={@_handleDownloadBuffered}>
      Download buffered logs
    </button>

  _renderRecord: (record, idx) ->
    {msg, fStory, action} = record
    if fStory and action?
      msg += " [#{action}]"
    segments = ansiColors.getStructured msg
    <li key={idx} style={_style.record}>
      {@_renderMsgSegments segments}
    </li>

  _renderMsgSegments: (segments) ->
    return null if not segments
    return null if not segments.length
    return segments.map (segment) =>
      if _.isString segment
        return segment
      <span style={segment.style}>
        {@_renderMsgSegments segment.children}
      </span>

  #-----------------------------------------------------
  _txMsg: (type, data) ->
    @props.msgSend {src: 'DT', type, data}

  _rxMsg: (msg) ->
    {src, type, result, data} = msg
    console.log "[DT] RX #{src}/#{type}", data
    switch type
      when 'CONNECT_REQUEST', 'CONNECT_RESPONSE'
        @setState {fEstablishedE2E: true, rootStory: []}
        if type is 'CONNECT_REQUEST' then @_txMsg 'CONNECT_RESPONSE'
      when 'LOGIN_REQUIRED'
        if @_lastCredentials
          @_handleSubmitLogin @_lastCredentials
        else
          @setState {fLoginRequired: true, loginStatus: 'LOGGED_OUT'}
      when 'LOGIN_RESPONSE' 
        if result is 'SUCCESS' then @setState {loginStatus: 'LOGGED_IN'}
      when 'BUFFERED_RECORDS_RESPONSE' 
        if result is 'SUCCESS' then @_rxRecords data
      when 'RECORDS' then @_rxRecords data
    return

  _rxRecords: (records) ->
    {rootStory} = @state
    rootStory = rootStory.concat records
    @setState {rootStory}

  _handleSubmitLogin: (credentials) ->
    @_lastCredentials = credentials
    @_txMsg 'LOGIN_REQUEST', credentials
    @setState {loginStatus: 'LOGGING_IN'}

  _handleDownloadBuffered: -> @_txMsg 'BUFFERED_RECORDS_REQUEST'

#-----------------------------------------------------
_style = 
  outer: 
    backgroundColor: 'white'
    height: '100%'
    padding: 4
  record:
    fontFamily: 'monospace'
    whiteSpace: 'pre'

module.exports = Root
