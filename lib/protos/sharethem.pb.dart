//
//  Generated code. Do not modify.
//  source: lib/protos/sharethem.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class SharedFileContentNotify extends $pb.GeneratedMessage {
  factory SharedFileContentNotify({
    SharedFile? file,
    $core.List<$core.int>? content,
  }) {
    final result = create();
    if (file != null) result.file = file;
    if (content != null) result.content = content;
    return result;
  }

  SharedFileContentNotify._();

  factory SharedFileContentNotify.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory SharedFileContentNotify.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SharedFileContentNotify', createEmptyInstance: create)
    ..aOM<SharedFile>(1, _omitFieldNames ? '' : 'file', subBuilder: SharedFile.create)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'content', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFileContentNotify clone() => SharedFileContentNotify()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFileContentNotify copyWith(void Function(SharedFileContentNotify) updates) => super.copyWith((message) => updates(message as SharedFileContentNotify)) as SharedFileContentNotify;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SharedFileContentNotify create() => SharedFileContentNotify._();
  @$core.override
  SharedFileContentNotify createEmptyInstance() => create();
  static $pb.PbList<SharedFileContentNotify> createRepeated() => $pb.PbList<SharedFileContentNotify>();
  @$core.pragma('dart2js:noInline')
  static SharedFileContentNotify getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SharedFileContentNotify>(create);
  static SharedFileContentNotify? _defaultInstance;

  @$pb.TagNumber(1)
  SharedFile get file => $_getN(0);
  @$pb.TagNumber(1)
  set file(SharedFile value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);
  @$pb.TagNumber(1)
  SharedFile ensureFile() => $_ensure(0);

  @$pb.TagNumber(4)
  $core.List<$core.int> get content => $_getN(1);
  @$pb.TagNumber(4)
  set content($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(1);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);
}

class GetSharedFilesRsp extends $pb.GeneratedMessage {
  factory GetSharedFilesRsp({
    $core.Iterable<SharedFile>? files,
  }) {
    final result = create();
    if (files != null) result.files.addAll(files);
    return result;
  }

  GetSharedFilesRsp._();

  factory GetSharedFilesRsp.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory GetSharedFilesRsp.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetSharedFilesRsp', createEmptyInstance: create)
    ..pc<SharedFile>(1, _omitFieldNames ? '' : 'files', $pb.PbFieldType.PM, subBuilder: SharedFile.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedFilesRsp clone() => GetSharedFilesRsp()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedFilesRsp copyWith(void Function(GetSharedFilesRsp) updates) => super.copyWith((message) => updates(message as GetSharedFilesRsp)) as GetSharedFilesRsp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSharedFilesRsp create() => GetSharedFilesRsp._();
  @$core.override
  GetSharedFilesRsp createEmptyInstance() => create();
  static $pb.PbList<GetSharedFilesRsp> createRepeated() => $pb.PbList<GetSharedFilesRsp>();
  @$core.pragma('dart2js:noInline')
  static GetSharedFilesRsp getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetSharedFilesRsp>(create);
  static GetSharedFilesRsp? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SharedFile> get files => $_getList(0);
}

class SharedFile extends $pb.GeneratedMessage {
  factory SharedFile({
    $core.String? fileName,
    $core.int? fileSize,
    $core.int? fileCrc,
  }) {
    final result = create();
    if (fileName != null) result.fileName = fileName;
    if (fileSize != null) result.fileSize = fileSize;
    if (fileCrc != null) result.fileCrc = fileCrc;
    return result;
  }

  SharedFile._();

  factory SharedFile.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory SharedFile.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SharedFile', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'fileName')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'fileSize', $pb.PbFieldType.OU3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'fileCrc', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFile clone() => SharedFile()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFile copyWith(void Function(SharedFile) updates) => super.copyWith((message) => updates(message as SharedFile)) as SharedFile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SharedFile create() => SharedFile._();
  @$core.override
  SharedFile createEmptyInstance() => create();
  static $pb.PbList<SharedFile> createRepeated() => $pb.PbList<SharedFile>();
  @$core.pragma('dart2js:noInline')
  static SharedFile getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SharedFile>(create);
  static SharedFile? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get fileName => $_getSZ(0);
  @$pb.TagNumber(1)
  set fileName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFileName() => $_has(0);
  @$pb.TagNumber(1)
  void clearFileName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get fileSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set fileSize($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFileSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearFileSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get fileCrc => $_getIZ(2);
  @$pb.TagNumber(3)
  set fileCrc($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFileCrc() => $_has(2);
  @$pb.TagNumber(3)
  void clearFileCrc() => $_clearField(3);
}

class GetSharedFilesReq extends $pb.GeneratedMessage {
  factory GetSharedFilesReq() => create();

  GetSharedFilesReq._();

  factory GetSharedFilesReq.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory GetSharedFilesReq.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetSharedFilesReq', createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedFilesReq clone() => GetSharedFilesReq()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedFilesReq copyWith(void Function(GetSharedFilesReq) updates) => super.copyWith((message) => updates(message as GetSharedFilesReq)) as GetSharedFilesReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSharedFilesReq create() => GetSharedFilesReq._();
  @$core.override
  GetSharedFilesReq createEmptyInstance() => create();
  static $pb.PbList<GetSharedFilesReq> createRepeated() => $pb.PbList<GetSharedFilesReq>();
  @$core.pragma('dart2js:noInline')
  static GetSharedFilesReq getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetSharedFilesReq>(create);
  static GetSharedFilesReq? _defaultInstance;
}

class SharedFileCompletedNotify extends $pb.GeneratedMessage {
  factory SharedFileCompletedNotify({
    $core.String? fileName,
    $core.bool? success,
    $core.String? message,
  }) {
    final result = create();
    if (fileName != null) result.fileName = fileName;
    if (success != null) result.success = success;
    if (message != null) result.message = message;
    return result;
  }

  SharedFileCompletedNotify._();

  factory SharedFileCompletedNotify.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory SharedFileCompletedNotify.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SharedFileCompletedNotify', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'fileName')
    ..aOB(2, _omitFieldNames ? '' : 'success')
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFileCompletedNotify clone() => SharedFileCompletedNotify()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedFileCompletedNotify copyWith(void Function(SharedFileCompletedNotify) updates) => super.copyWith((message) => updates(message as SharedFileCompletedNotify)) as SharedFileCompletedNotify;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SharedFileCompletedNotify create() => SharedFileCompletedNotify._();
  @$core.override
  SharedFileCompletedNotify createEmptyInstance() => create();
  static $pb.PbList<SharedFileCompletedNotify> createRepeated() => $pb.PbList<SharedFileCompletedNotify>();
  @$core.pragma('dart2js:noInline')
  static SharedFileCompletedNotify getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SharedFileCompletedNotify>(create);
  static SharedFileCompletedNotify? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get fileName => $_getSZ(0);
  @$pb.TagNumber(1)
  set fileName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFileName() => $_has(0);
  @$pb.TagNumber(1)
  void clearFileName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get success => $_getBF(1);
  @$pb.TagNumber(2)
  set success($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSuccess() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuccess() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);
}

/// Jika Anda menggunakan gRPC, Anda mungkin juga punya pesan seperti ini:
class FileChunk extends $pb.GeneratedMessage {
  factory FileChunk({
    $core.String? sessionId,
    $core.String? fileName,
    $core.int? fileSize,
    $core.int? fileCrc,
    $core.List<$core.int>? chunkData,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (fileName != null) result.fileName = fileName;
    if (fileSize != null) result.fileSize = fileSize;
    if (fileCrc != null) result.fileCrc = fileCrc;
    if (chunkData != null) result.chunkData = chunkData;
    return result;
  }

  FileChunk._();

  factory FileChunk.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory FileChunk.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FileChunk', createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'fileName')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'fileSize', $pb.PbFieldType.OU3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'fileCrc', $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'chunkData', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileChunk clone() => FileChunk()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileChunk copyWith(void Function(FileChunk) updates) => super.copyWith((message) => updates(message as FileChunk)) as FileChunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FileChunk create() => FileChunk._();
  @$core.override
  FileChunk createEmptyInstance() => create();
  static $pb.PbList<FileChunk> createRepeated() => $pb.PbList<FileChunk>();
  @$core.pragma('dart2js:noInline')
  static FileChunk getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FileChunk>(create);
  static FileChunk? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get fileName => $_getSZ(1);
  @$pb.TagNumber(2)
  set fileName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFileName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFileName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get fileSize => $_getIZ(2);
  @$pb.TagNumber(3)
  set fileSize($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFileSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearFileSize() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get fileCrc => $_getIZ(3);
  @$pb.TagNumber(4)
  set fileCrc($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFileCrc() => $_has(3);
  @$pb.TagNumber(4)
  void clearFileCrc() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get chunkData => $_getN(4);
  @$pb.TagNumber(5)
  set chunkData($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasChunkData() => $_has(4);
  @$pb.TagNumber(5)
  void clearChunkData() => $_clearField(5);
}

class FileSendResponse extends $pb.GeneratedMessage {
  factory FileSendResponse({
    $core.bool? success,
    $core.String? message,
    $core.String? fileName,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (message != null) result.message = message;
    if (fileName != null) result.fileName = fileName;
    return result;
  }

  FileSendResponse._();

  factory FileSendResponse.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(data, registry);
  factory FileSendResponse.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FileSendResponse', createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOS(3, _omitFieldNames ? '' : 'fileName')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileSendResponse clone() => FileSendResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileSendResponse copyWith(void Function(FileSendResponse) updates) => super.copyWith((message) => updates(message as FileSendResponse)) as FileSendResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FileSendResponse create() => FileSendResponse._();
  @$core.override
  FileSendResponse createEmptyInstance() => create();
  static $pb.PbList<FileSendResponse> createRepeated() => $pb.PbList<FileSendResponse>();
  @$core.pragma('dart2js:noInline')
  static FileSendResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FileSendResponse>(create);
  static FileSendResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get fileName => $_getSZ(2);
  @$pb.TagNumber(3)
  set fileName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFileName() => $_has(2);
  @$pb.TagNumber(3)
  void clearFileName() => $_clearField(3);
}

class ShareThemApi {
  final $pb.RpcClient _client;

  ShareThemApi(this._client);

  $async.Future<GetSharedFilesRsp> getSharedFiles($pb.ClientContext? ctx, GetSharedFilesReq request) =>
    _client.invoke<GetSharedFilesRsp>(ctx, 'ShareThem', 'GetSharedFiles', request, GetSharedFilesRsp())
  ;
  $async.Future<FileSendResponse> sendFile($pb.ClientContext? ctx, FileChunk request) =>
    _client.invoke<FileSendResponse>(ctx, 'ShareThem', 'SendFile', request, FileSendResponse())
  ;
  $async.Future<SharedFileCompletedNotify> streamFileToReceiver($pb.ClientContext? ctx, SharedFileContentNotify request) =>
    _client.invoke<SharedFileCompletedNotify>(ctx, 'ShareThem', 'StreamFileToReceiver', request, SharedFileCompletedNotify())
  ;
}


const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
