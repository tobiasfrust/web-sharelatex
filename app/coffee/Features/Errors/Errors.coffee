NotFoundError = (message) ->
	error = new Error(message)
	error.name = "NotFoundError"
	error.__proto__ = NotFoundError.prototype
	return error
NotFoundError.prototype.__proto__ = Error.prototype

ServiceNotConfiguredError = (message) ->
	error = new Error(message)
	error.name = "ServiceNotConfiguredError"
	error.__proto__ = ServiceNotConfiguredError.prototype
	return error
ServiceNotConfiguredError.prototype.__proto__ = Error.prototype

TooManyRequestsError = (message) ->
	error = new Error(message)
	error.name = "TooManyRequestsError"
	error.__proto__ = TooManyRequestsError.prototype
	return error
TooManyRequestsError.prototype.__proto__ = Error.prototype

InvalidNameError = (message) ->
	error = new Error(message)
	error.name = "InvalidNameError"
	error.__proto__ = InvalidNameError.prototype
	return error
InvalidNameError.prototype.__proto__ = Error.prototype

UnsupportedFileTypeError = (message) ->
	error = new Error(message)
	error.name = "UnsupportedFileTypeError"
	error.__proto__ = UnsupportedFileTypeError.prototype
	return error
UnsupportedFileTypeError.prototype.__proto__ = Error.prototype

UnsupportedBrandError = (message) ->
	error = new Error(message)
	error.name = "UnsupportedBrandError"
	error.__proto__ = UnsupportedBrandError.prototype
	return error
UnsupportedBrandError.prototype.__proto__ = Error.prototype

UnsupportedExportRecordsError = (message) ->
	error = new Error(message)
	error.name = "UnsupportedExportRecordsError"
	error.__proto__ = UnsupportedExportRecordsError.prototype
	return error
UnsupportedExportRecordsError.prototype.__proto__ = Error.prototype

V1HistoryNotSyncedError = (message) ->
	error = new Error(message)
	error.name = "V1HistoryNotSyncedError"
	error.__proto__ = V1HistoryNotSyncedError.prototype
	return error
V1HistoryNotSyncedError.prototype.__proto__ = Error.prototype

ProjectHistoryDisabledError = (message) ->
	error = new Error(message)
	error.name = "ProjectHistoryDisabledError"
	error.__proto__ = ProjectHistoryDisabledError.prototype
	return error
ProjectHistoryDisabledError.prototype.__proto__ = Error.prototype

V1ConnectionError = (message) ->
	error = new Error(message)
	error.name = "V1ConnectionError"
	error.__proto__ = V1ConnectionError.prototype
	return error
V1ConnectionError.prototype.__proto__ = Error.prototype

UnconfirmedEmailError = (message) ->
	error = new Error(message)
	error.name = "UnconfirmedEmailError"
	error.__proto__ = UnconfirmedEmailError.prototype
	return error
UnconfirmedEmailError.prototype.__proto__ = Error.prototype

EmailExistsError = (message) ->
	error = new Error(message)
	error.name = "EmailExistsError"
	error.__proto__ = EmailExistsError.prototype
	return error
EmailExistsError.prototype.__proto__ = Error.prototype

InvalidError = (message) ->
	error = new Error(message)
	error.name = "InvalidError"
	error.__proto__ = InvalidError.prototype
	return error
InvalidError.prototype.__proto__ = Error.prototype

AccountMergeError = (message) ->
	error = new Error(message)
	error.name = "AccountMergeError"
	error.__proto__ = AccountMergeError.prototype
	return error
AccountMergeError.prototype.__proto__ = Error.prototype

module.exports = Errors =
	NotFoundError: NotFoundError
	ServiceNotConfiguredError: ServiceNotConfiguredError
	TooManyRequestsError: TooManyRequestsError
	InvalidNameError: InvalidNameError
	UnsupportedFileTypeError: UnsupportedFileTypeError
	UnsupportedBrandError: UnsupportedBrandError
	UnsupportedExportRecordsError: UnsupportedExportRecordsError
	V1HistoryNotSyncedError: V1HistoryNotSyncedError
	ProjectHistoryDisabledError: ProjectHistoryDisabledError
	V1ConnectionError: V1ConnectionError
	UnconfirmedEmailError: UnconfirmedEmailError
	EmailExistsError: EmailExistsError
	InvalidError: InvalidError
	AccountMergeError: AccountMergeError
