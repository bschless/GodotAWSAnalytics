extends Node

export(String) var identity_pool_id = ""
export(String) var account_id = ""
export(String) var app_id = ""
export(String) var app_package_name = ""
export(String) var app_title = ""
export(String) var api_endpoint = ""
export(String) var api_key = ""
export(String) var app_version_code = ""
export(String) var app_version_name = ""
export(bool) var log_to_output = false

var _session_id = ""
var _request
var _request_data
var _request_callback
var _refreshing_credentials = false
var _refreshing_request
var _previous_request
var _session_start_timestamp = ""
var _session_start_unix = 0
var _focus_lost_unix = 0
var _focus_lost_max = 5
var _focus_lost_time = 0
var _has_focus = true
var _settings = {
	identity = {
		identity_id = "",
		access_key_id = "",
		expiration = 0,
		secret_key = "",
		session_token = ""
	},
	client_id = ""
}
var _settings_filename = "godot.analytics"
func get_settings():
	return _settings
func load_data():
	var data = File.new()
	if not data.file_exists("user://"+_settings_filename):
		return false
	data.open("user://"+_settings_filename, File.READ)
	while not data.eof_reached():
		var settings_json = parse_json(data.get_line())
		if settings_json == null:
			break
		_settings = settings_json
	data.close()
	return true
func _save_data():
	if _settings.client_id == "":
		_settings.client_id = _create_guid()
	var data = File.new()
	data.open("user://"+_settings_filename, File.WRITE)
	data.store_line(JSON.print(_settings))
	data.close()
func _ready():
	pause_mode = PAUSE_MODE_PROCESS
	get_tree().set_auto_accept_quit(false)
	_request = HTTPRequest.new()
	_request.use_threads = true
	add_child(_request)
	_refreshing_request = HTTPRequest.new()
	_refreshing_request.use_threads = true
	add_child(_refreshing_request)
	_refreshing_request.connect("request_completed", self, "_identity_credentials_received")
	if !load_data():
		_save_data()
		_settings_data_ready()
	else:
		_settings_data_ready()
func _process(delta):
	if !_has_focus:
		if _session_id != "":
			_focus_lost_time += delta
			if _focus_lost_time > _focus_lost_max:
				_end_session()
func _settings_data_ready():
	if _settings.identity.identity_id != "":
		_start_session()
	else:
		_request_new_identity_id()
func _create_request_data(event_type, attributes = {}, metrics = {}):
	var payload = {
		timestamp = _get_amz_timestamp(),
		eventType = event_type,
		session = JSON.print({
			id = _session_id,
			startTimestamp = _session_start_timestamp
		}),
		clientContext = _get_client_context(),
		secretAccessKey = _settings.identity.secret_key,
		accessKeyId = _settings.identity.access_key_id,
		sessionToken = _settings.identity.session_token,
		attributes = JSON.print(attributes),
		metrics = JSON.print(metrics)
	}
	return payload
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		_end_session()
		yield(get_tree().create_timer(1.0),"timeout")
		get_tree().quit()
	if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
		_has_focus = false
		_focus_lost_unix = OS.get_unix_time()
	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		_focus_lost_time = 0
		_has_focus = true
		if _session_id == "":
			_start_session()
func _start_session():
	if _session_id != "":
		return
	if log_to_output:
		print("starting session")
	_session_start_unix = OS.get_unix_time()
	_session_id = _create_guid()
	_session_start_timestamp = _get_amz_timestamp()
	var request_data = _create_request_data('_session.start')
	_make_request(request_data, "_session_start_complete")
	pass
func _end_session():
	if log_to_output:
		print("ending session")
	var request_data = _create_request_data('_session.stop')
	request_data.timestamp = _get_amz_timestamp()
	request_data.session = JSON.print({
		id = _session_id,
		startTimestamp = _session_start_timestamp,
		stopTimestamp = request_data.timestamp,
		duration = (OS.get_unix_time() - _session_start_unix) * 1000
	})
	_session_id = ""
	_make_request(request_data, "_session_end_complete")
func _session_end_complete(result, code, headers, body):
	var response = JSON.parse(body.get_string_from_utf8()).result
	if log_to_output:
		print("end session response: ")
		print(response)
	_request.disconnect("request_completed", self, "_session_end_complete")
	if !_check_error(response):
		_previous_request = true
		_request_credentials_for_identity()
		return
func _event_callback(result, code, headers, body):
	var response = JSON.parse(body.get_string_from_utf8()).result
	if log_to_output:
		print("event response: ")
		print(response)
	_request.disconnect("request_completed", self, "_event_callback")
	if !_check_error(response):
		_previous_request = true
		_request_credentials_for_identity()
		return
func _check_error(response):
	response = JSON.print(response)
	if (response.find("expired") > -1 || response.find("invalid") > -1) && response.find("token") > -1:
		return false
	return true
func _make_request(request_data, callback):
	_request_data = request_data
	_request_callback = callback
	if !_token_valid(request_data):
		_previous_request = true
		_request_credentials_for_identity()
	else:
		_request.connect("request_completed", self, callback)
		var headers = ["Content-Type: application/json"]
		if api_key.length() > 1:
			headers.append("x-api-key: "+api_key)
		_request.request(api_endpoint, headers, true, HTTPClient.METHOD_POST, JSON.print(request_data))
	pass
func _token_valid(request_data):
	var current_time = OS.get_unix_time_from_datetime(OS.get_date(true))
	if current_time > _settings.identity.expiration:
		return false
	return true
func record_event(event_type, attributes = {}, metrics = {}):
	var request_data = _create_request_data(event_type, attributes, metrics)
	if log_to_output:
		print("sending event")
	_make_request(request_data, "_event_callback")
	pass
func _session_start_complete(result, code, headers, body):
	var response = JSON.parse(body.get_string_from_utf8()).result
	if log_to_output:
		print("start session response: ")
		print(response)
	_request.disconnect("request_completed", self, "_session_start_complete")
	if !_check_error(response):
		_previous_request = true
		_request_credentials_for_identity()
		return
func _get_client_context():
	return JSON.print({
		client = {
			app_package_name = app_package_name,
			app_title = app_title,
			app_version_code = app_version_code,
			app_version_name = app_version_name,
			client_id = _settings.client_id
		},
		custom = {},
		env = {
			platform = _get_platform(OS.get_name()),
		},
		version = "v2.0",
		services = {
			mobile_analytics = {
				app_id = app_id
			}
		}
	})
func _get_platform(os_name):
	match os_name:
		"Android":
			return os_name
		"iOS":
			return "iPhone OS"
		"Windows":
			return os_name
		"X11":
			return "Linux"
		"OSX":
			return "Mac OS"
		"HTML5":
			return os_name
func _request_new_identity_id():
	if log_to_output:
		print("requesting new federated identity id")
	var request = HTTPRequest.new()
	add_child(request)
	_request.use_threads = true
	var payload = {
		IdentityPoolId = identity_pool_id,
		AccountId = account_id
	}
	_request.connect("request_completed", self, "_identity_id_received")
	_request.request("https://cognito-identity.us-east-1.amazonaws.com", ["Host: cognito-identity.us-east-1.amazonaws.com","X-Amz-Date: "+_get_amz_date(true), "X-Amz-Target: com.amazonaws.cognito.identity.model.AWSCognitoIdentityService.GetId", "Content-Type: application/x-amz-json-1.1"], true, HTTPClient.METHOD_POST, JSON.print(payload))
func _identity_id_received(result, code, headers, body):
	var response = JSON.parse(body.get_string_from_utf8()).result
	if log_to_output:
		print("identity id received")
		print(response)
	_request.disconnect("request_completed", self, "_identity_id_received")
	_settings.identity.identity_id = response.IdentityId
	_save_data()
	_request_credentials_for_identity()
	pass
func _request_credentials_for_identity():
	if log_to_output:
		print("requesting credentials for identity")
	if _refreshing_credentials:
		return
	_refreshing_credentials = true
	var payload = {
		IdentityId = _settings.identity.identity_id,	
	}
	_refreshing_request.request("https://cognito-identity.us-east-1.amazonaws.com", ["Host: cognito-identity.us-east-1.amazonaws.com","X-Amz-Date: "+_get_amz_date(true), "X-Amz-Target: com.amazonaws.cognito.identity.model.AWSCognitoIdentityService.GetCredentialsForIdentity", "Content-Type: application/x-amz-json-1.1"], true, HTTPClient.METHOD_POST, JSON.print(payload))
func _identity_credentials_received(result, code, headers, body):
	_refreshing_credentials = false
	var response = JSON.parse(body.get_string_from_utf8()).result
	if log_to_output:
		print("received credentials for identity")
		print(response)
	_settings.identity.access_key_id = response.Credentials.AccessKeyId
	_settings.identity.expiration = response.Credentials.Expiration
	_settings.identity.secret_key = response.Credentials.SecretKey
	_settings.identity.session_token = response.Credentials.SessionToken
	_save_data()
	if _previous_request:
		_previous_request = false
		_request_data.sessionToken = _settings.identity.session_token
		_request_data.accessKeyId = _settings.identity.access_key_id
		_request_data.secretAccessKey = _settings.identity.secret_key
		_make_request(_request_data, _request_callback)
	else:
		_start_session()
func _get_amz_date(with_time):
	var datetime = OS.get_datetime(true)
	var year = String(datetime.year)
	var month = _add_leading_zero(datetime.month)
	var day = _add_leading_zero(datetime.day)
	var hour = _add_leading_zero(datetime.hour)
	var minute = _add_leading_zero(datetime.minute)
	var second = _add_leading_zero(datetime.second)
	if with_time:
		return year + month + day + "T" + hour + minute + second + "Z"
	return year + month + day
func _get_amz_timestamp():
	var datetime = OS.get_datetime(true)
	var year = String(datetime.year)
	var month = _add_leading_zero(datetime.month)
	var day = _add_leading_zero(datetime.day)
	var hour = _add_leading_zero(datetime.hour)
	var minute = _add_leading_zero(datetime.minute)
	var second = _add_leading_zero(datetime.second)
	return year +"-" + month + "-" + day + "T" + hour +":"+ minute +":" + second +".0123Z"
func _add_leading_zero(number):
	var number_string = String(number)
	if number_string.length() == 1:
		return "0"+number_string
	return number_string
func _create_guid():
	randomize()
	var guid = ""
	var random_chars = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","A","B","C","D","E","F","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","0","1","2","3","4","5","6","7","8","9","0","1","2","3","4","5","6","7","8","9","0","1","2","3","4","5","6","7","8","9","0","1","2","3","4","5","6","7","8","9"]
	for i in range(0, 32):
		guid += random_chars[randi() % (random_chars.size() - 1)]
	var g1 = guid.substr(0,8)
	var g2 = guid.substr(8,4)
	var g3 = guid.substr(12,4)
	var g4 = guid.substr(16, 4)
	var g5 = guid.substr(20, 12)
	return g1 + "-" + g2 + "-" + g3 + "-" + g4 + "-" + g5