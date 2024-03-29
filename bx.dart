// EXAMPLE: https://dart.dev/tutorials/server/cmdline
// EXAMPLE: dart create -t console-full cli

import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:windows1251/windows1251.dart';
import 'package:xml/xml.dart' as xml;

var REAL_BIN = p.dirname(Platform.script.toFilePath());
var PATH_ORIGINAL = Platform.environment['PATH'] ?? '';
var ENV_PATH_SEP = Platform.isWindows? ';' : ':';
var ENV_LOCAL;
var ARGV;

const BASE_ENV_NAME = '.env';
const SOLUTION_REPOS_SEP = ';';

final chars = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z'
];
final digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
final addchars = ['!', '_', '-', '.', ',', '|'];

final chars_digits = [...chars, ...digits];

final chars_digits_specs = [...chars, ...digits, ...addchars];

random_password() {
  final length = 20;
  var r = new Random();

  var result = [];
  result.add(addchars[r.nextInt(addchars.length - 1)]);
  for (var i = 0; i < length; i++) {
    result.add(chars_digits_specs[r.nextInt(chars_digits_specs.length - 1)]);
  }
  result.add(addchars[r.nextInt(addchars.length - 1)]);
  result.add(digits[r.nextInt(digits.length - 1)]);

  return result.join();
}

random_name() {
  final length = 9;
  var r = new Random();

  var result = [];
  for (var i = 0; i < length; i++) {
    result.add(chars_digits[r.nextInt(chars_digits.length - 1)]);
  }

  return 'usr' + result.join();
}

chdir(dir) {
  Directory.current = dir;
}

get_env(name) {
  if (ENV_LOCAL == null) {
    return '';
  }
  if (ENV_LOCAL.containsKey(name)) {
    return (ENV_LOCAL[name] ?? '');
  }
  var ENV = Platform.environment;

  return (ENV[name] ?? '');
}

get_user() async {
  return p.basename(await runReturnContent('whoami'));
}

get_home() {
  if (Platform.isMacOS) {
    return get_env('HOME');
  } else if (Platform.isLinux) {
    return get_env('HOME');
  } else if (Platform.isWindows) {
    return get_env('USERPROFILE');
  }
  return '/home/' + get_user();
}

get_site_host(path) {
  var sitehost = p.basename(path);
  if (sitehost == 'app') {
    sitehost = p.basename(p.dirname(path));
  }

  return sitehost;
}

die(msg) {
  print(msg);
  exit(0);
}

confirm_continue(title) {
  print(title + " Type 'yes' to continue: ");
  var line = stdin.readLineSync();

  return (line ?? '').trim() == 'yes';
}

require_site_root(basePath) {
  var sitesDir = get_sites_root();
  if (basePath == '') {
    die('''
Site root not found.
Run command from your public folder of site [ ${sitesDir}yoursitefolder/app/ ]
''');
  }
}

check_command(cmd) async {
  ProcessResult result = await Process.run('which', [cmd]);
  return result.exitCode == 0;
}

require_command(cmd) async {
  if (!await check_command(cmd)) {
    die('[' + cmd + '] command - not found.');
  }
}

require_file(path) async {
  if (!File(path).existsSync()) {
    die('File [' + path + '] - not found.');
  }
}

is_bx_debug() {
  return get_env('BX_DEBUG') == '1';
}

is_wsl() {
  return get_env('USE_WSL') == '1';
}

is_ubuntu() async {
  if (!Platform.isLinux) {
    return false;
  }
  if (!await check_command('lsb_release')) {
    return false;
  }
  ProcessResult result;
  try {
    result = await Process.run('lsb_release', ['-a']);
  } catch (e) {
    return false;
  }
  if (result.exitCode != 0) {
    return false;
  }
  return (result.stdout.indexOf('Ubuntu') >= 0) || (result.stdout.indexOf('ubuntu') >= 0);
}

is_mingw() {
  var msystem = get_env('MSYSTEM');
  if ((msystem == 'MINGW64') || (msystem == 'MINGW32') || (msystem == 'MSYS')) {
    return true;
  }

  return false;
}

is_windows_32bit() {
  return get_env('PROCESSOR_ARCHITECTURE').indexOf('x86') >= 0;
}

quote_args(args) {
  var result = [];
  for (final arg in args) {
    if ((arg.indexOf(' ') >= 0) ||
        (arg.indexOf('?') >= 0) ||
        (arg.indexOf('>') >= 0) ||
        (arg.indexOf('<') >= 0) ||
        (arg.indexOf('|') >= 0)) {
      result.add("'" + arg + "'");
    } else {
      result.add(arg);
    }
  }
  return result.join(' ');
}

// https://api.dart.dev/be/178268/dart-io/dart-io-library.html
runReturnContent(cmd, [args = null]) async {
  if (args == null) {
    args = [];
  }
  try {
    ProcessResult result = await Process.run(cmd, new List<String>.from(args), environment: ENV_LOCAL);
    return result.stdout.trimRight();
  } catch (e) {
    print('Error on running command:');
    print(e);
    return '';
  }
}

run(cmd, args, [runInShell = false]) async {
  if (is_bx_debug()) {
    print('RUN: ' + cmd + ' ' + quote_args(args));
  }
  try {
    ProcessResult result =
        await Process.run(cmd, new List<String>.from(args), environment: ENV_LOCAL, runInShell: runInShell);
    var output = result.stdout.trimRight();
    if (output.length > 0) {
      print(output);
    }
    var errors = result.stderr.trimRight();
    if (errors.length > 0) {
      print('');
      print('=======');
      print('');
      print(errors);
    }
    return result.exitCode;
  } catch (e) {
    print('Error on running command:');
    print(e);
    return -1;
  }
}

start(cmd, args) async {
  Process.start(
    cmd,
    new List<String>.from(args),
    environment: ENV_LOCAL,
    runInShell: false,
    mode: ProcessStartMode.detached
  );
}

// для не интерактивных команд с перенаправлением
system(cmdLine) async {
  return run('perl', ['-e', 'system("' + cmdLine.replaceAll('"', '\\"') + '");']);
}

runInteractive(cmd, List<String> args) async {
  // https://pub.dev/packages/process_run/install
  var process = await Process.start(
    cmd,
    args,
    mode: ProcessStartMode.inheritStdio,
    environment: ENV_LOCAL
  );
  //stdout.addStream(process.stdout);
  //stderr.addStream(process.stderr);
  await process.exitCode;
}

/*
runWithInputFromFile(cmd, args, inputFle) async {
  var process = await Process.start(cmd, new List<String>.from(args));
  process.stdout.transform(utf8.decoder).forEach(print);
  //process.stdin.writeln(new File(inputFle).readAsStringSync());
}
*/

sudo_run(cmd, args) async {
  if (!await is_ubuntu()) {
    return run(cmd, args);
  }
  if (get_env('BX_ROOT_USER') == '1') {
    return run(cmd, args);
  }
  args.insert(0, cmd);

  return run('sudo', args);
}

service(name, action) async {
  if (is_wsl()) {
    await sudo_run('service', [name, action]);
  } else {
    await sudo_run('systemctl', [action, name]);
  }
}

run_php(args) async {
  var phpBin = get_env('SOLUTION_PHP_BIN');
  if (phpBin == '') {
    phpBin = 'php';
    await require_command(phpBin);
  } else if (!Platform.isWindows) {
    require_file(phpBin);
    var phpBinDir = p.dirname(phpBin);
    ENV_LOCAL['LD_LIBRARY_PATH'] = p.dirname(phpBinDir) + '/shared-libs';
    ENV_LOCAL['PATH'] = phpBinDir + ENV_PATH_SEP + PATH_ORIGINAL;
  } else {
    require_file(phpBin);
    //TODO!!! for windows
  }

  List<String> cmdArgs = new List.from([]);
  var phpArgs = get_env('SOLUTION_PHP_ARGS');
  if (phpArgs != '') {
    for (final arg in phpArgs.split(' ')) {
      cmdArgs.add(arg.trim());
    }
  }
  for (final arg in args) {
    cmdArgs.add(arg);
  }
  //!!! print(phpBin); print(cmdArgs);

  await runInteractive(phpBin, cmdArgs);
}

request_useragent() {
  return 'Mozilla/5.0 (X11; Linux x86_64; rv:66.0) Gecko/20100101 Firefox/66.0';
}

request_get(url, [outfile = '']) async {
  await require_command('curl');

  var args = ['-s', '-L', url, '-A', request_useragent()];
  if (outfile != '') {
    args.add('-o');
    args.add(outfile);
  }

  return run('curl', args);
}

zip_archive_extract(src, dest) async {
  await require_command('unzip');

  return run('unzip', ['-o', src, '-d', dest]);
}

tgz_archive_extract(src, dest, [dirFromArchive = '']) async {
  await require_command('tar');

  if (is_mingw()) {
    src = src.replaceAll('\\', '/').replaceFirst('C:', '/c');
  }

  var args = ['-xzf', src];
  if (dest != '') {
    args.add('-C');
    args.add(dest);
  }
  if (dirFromArchive != '') {
    args.add(dirFromArchive);
  }

  return run('tar', args);
}

any_archive_extract(src, dest) async {
  if (p.extension(src) == '.zip') {
    return zip_archive_extract(src, dest);
  } else if (p.extension(src, 2) == '.tar.gz') {
    return tgz_archive_extract(src, dest);
  }
}

file_get_contents(filename) {
  final file = new File(filename);
  return file.readAsStringSync();
}

file_get_contents_win(filename) {
  final file = new File(filename);
  return windows1251.decode(file.readAsBytesSync());
}

file_put_contents(filename, content) {
  final file = new File(filename);
  file.writeAsStringSync(content);

  return 1;
}

file_put_contents_win(filename, content) {
  final file = new File(filename);
  file.writeAsBytesSync(windows1251.encode(content));

  return 1;
}

sudo_patch_file(fname, content) async {
  if (!File(fname).existsSync()) {
    return;
  }
  var path = get_env('HOME');
  var tmp = path + '/.patch.' + p.basename(fname) + '.tmp';
  var originalContent = file_get_contents(fname);
  if (originalContent.indexOf(content) < 0) {
    content = originalContent + "\n" + content + "\n";
    file_put_contents(tmp, content);
    await sudo_run('mv', [tmp, fname]);
  }
}

load_env_file(path) async {
  Map<String, String> result = {};
  if (!File(path).existsSync()) {
    return result;
  }

  final input = new File(path).openRead();
  final fields = await input
      .transform(utf8.decoder)
      .transform(new CsvToListConverter(fieldDelimiter: '=', textDelimiter: '"', textEndDelimiter: '"', eol: "\n"))
      .toList();

  for (final row in fields) {
    var key = row[0].trim();
    if (key == '') {
      continue;
    }
    if (key.substring(0, 1) == '#') {
      continue;
    }
    var value = row[1].toString().trim();
    result[key] = value;
  }

  return result;
}

load_env(path) async {
  // load tool config .env file
  Map<String, String> result = await load_env_file(REAL_BIN + '/' + BASE_ENV_NAME);

  // load project config .env file
  result.addAll(await load_env_file(path));

  // load current env .env file
  var prefix = Platform.environment['BX_ENV'] ?? '';
  if (prefix != '') {
    result.addAll(await load_env_file(path + '.' + prefix));
  }

  return result;
}

getcwd() {
  return Directory.current.path;
}

detect_site_root(path, [checkVars = true]) {
  if (path == '') {
    path = getcwd();
  }
  if (File(path + '/' + BASE_ENV_NAME).existsSync()) {
    if (checkVars) {
      var configContent = file_get_contents(path + '/' + BASE_ENV_NAME);
      if ((configContent.indexOf('APP_URL=') >= 0) || (configContent.indexOf('SOLUTION_GIT_REPOS=') >= 0)) {
        return path;
      }
    } else {
      return path;
    }
  }
  if ((path != '') && (path != p.dirname(path))) {
    return detect_site_root(p.dirname(path));
  }

  return '';
}

bitrix_minimize() async {
  var removeDirs = [
    // ненужные компоненты
    'bitrix/modules/iblock/install/components/bitrix',
    'bitrix/modules/fileman/install/components/bitrix',
    // ненужные модули
    'bitrix/modules/landing', // слишком много файлов в модуле
    'bitrix/modules/highloadblock',
    'bitrix/modules/perfmon',
    'bitrix/modules/bitrixcloud',
    'bitrix/modules/translate',
    'bitrix/modules/compression',
    'bitrix/modules/seo',
    'bitrix/modules/search',
    // ненужные демо решения
    'bitrix/modules/bitrix.sitecorporate',
    'bitrix/wizards/bitrix/demo',
  ];
  for (final dir in removeDirs) {
    if (Directory(dir).existsSync()) {
      //TODO!!! replace rm -Rf to new Directory(dir).deleteSync(recursive: true);
      await run('rm', ['-Rf', dir]);
    }
  }
}

bitrix_micromize() async {
  var bitrixExcludeDirs = {
    'cache': 1,
    'managed_cache': 1,
    'modules': 1,
    'php_interface': 1,
  };
  var bitrixExcludeFiles = {
    '.settings.php': 1,
  };
  var dirName = './bitrix';

  if (!Directory(dirName).existsSync()) {
    die('Could not open ' + dirName + ' for reading');
  }

  var contents = new Directory(dirName).listSync();
  for (var f in contents) {
    var name = p.basename(f.path);
    if (bitrixExcludeDirs.containsKey(name) || bitrixExcludeFiles.containsKey(name)) {
      continue;
    }
    if (f is Directory) {
      await run('rm', ['-Rf', f.path]);
    } else if (f is File) {
      f.deleteSync();
    }
  }

  var removeFiles = {
    '.access.php',
    //'.htaccess',
    //'index.php',
    'install.config',
    'license.html',
    'license.php',
    'readme.html',
    'readme.php',
    'web.config',
    'bitrix/modules/main/classes/mysql/database_mysql.php',
  };
  for (var fname in removeFiles) {
    if (File(fname).existsSync()) {
      File(fname).deleteSync();
    }
  }
}

action_help([basePath = '']) async {
  await run('cat', [REAL_BIN + '/README.md']);
}

action_fetch([basePath = '']) async {
  var urlEditions = {
    'micro': get_env('BITRIX_SRC_MICRO'),
    'core': get_env('BITRIX_SRC_CORE'),
    'start': get_env('BITRIX_SRC_START'),
    'business': get_env('BITRIX_SRC_BUSINESS'),
    'crm': get_env('BITRIX_SRC_CRM'),
    'setup': get_env('BITRIX_SRC_SETUP'),
    'restore': get_env('BITRIX_SRC_RESTORE'),
    'test': get_env('BITRIX_SRC_TEST'),
  };
  var outputFile = '.bitrix.tar.gz';
  var extractOptions = '';

  var edition = (ARGV.length > 1) ? ARGV[1] : 'start';
  if (!urlEditions.containsKey(edition)) {
    edition = 'start';
  }

  if (File(outputFile).existsSync()) {
    File(outputFile).deleteSync();
  }

  if (edition == 'setup') {
    outputFile = 'bitrixsetup.php';
  } else if (edition == 'restore') {
    outputFile = 'restore.php';
  } else if (edition == 'test') {
    outputFile = 'bitrix_server_test.php';
  } else if (edition == 'micro') {
    extractOptions = './bitrix/modules';
  }
  var srcUrl = urlEditions[edition];
  print("Loading $srcUrl...");
  await request_get(srcUrl, outputFile);

  if (!File(outputFile).existsSync()) {
    die('Error on loading bitrix edition ' + (srcUrl ?? ''));
  }

  if ((edition == 'setup') || (edition == 'restore') || (edition == 'test')) {
    exit(0);
  }

  print('Extracting files...');
  await tgz_archive_extract(outputFile, '', extractOptions);
  File(outputFile).deleteSync();

  if (edition == 'core') {
    print('Minimize for core...');
    await bitrix_minimize();
  } else if (edition == 'micro') {
    print('Micromize...');
    await bitrix_minimize();
    await bitrix_micromize();
  }
}

ftp_conn_str() {
  if (get_env('DEPLOY_SERVER') == '') {
    return '';
  }

  return get_env('DEPLOY_METHOD') +
      '://' +
      get_env('DEPLOY_USER') +
      ':' +
      get_env('DEPLOY_PASSWORD') +
      '@' +
      get_env('DEPLOY_SERVER') +
      get_env('DEPLOY_PORT') +
      get_env('DEPLOY_PATH');
}

ssh_exec_remote([cmd = '']) {
  var port = get_env('DEPLOY_PORT');
  if (port != '') {
    port = '-p' + port.substring(1, port.length);
  }

  List<String> args = [
    'sshpass',
    '-p',
    get_env('DEPLOY_PASSWORD'),
    'ssh',
    get_env('DEPLOY_USER') + '@' + get_env('DEPLOY_SERVER'),
  ];
  if (port != '') {
    args.add(port);
  }
  args.add('-t');

  var commandLine = '';

  var deployPath = get_env('DEPLOY_PATH');
  if (deployPath != '') {
    commandLine += 'cd ' + deployPath + ' && ';
  }

  if (cmd == '') {
    cmd = 'bash --login';
  }
  commandLine += cmd;

  if (commandLine != '') {
    args.add(commandLine);
  }

  /*

  //TODO!!! возможность передавать пароль и логин из .env при выполнеии команды

  https://stackoverflow.com/questions/12202587/automatically-enter-ssh-password-with-script

  #!/usr/bin/expect

  set timeout 20

  set cmd [lrange $argv 1 end]
  set password [lindex $argv 0]

  eval spawn $cmd
  expect "password:"
  send "$password\r";
  interact

  ---

  #!/usr/bin/expect -f
  spawn ssh HOSTNAME
  expect "login:"
  send "username\r"
  expect "Password:"
  send "password\r"
  interact

  https://linuxtechlab.com/how-to-use-ssh-command-with-password-in-single-line/ - 2- Using the ‘EXPECT’ command

  */

  return args;
}

get_ssh_command() {
  if (get_env('DEPLOY_SERVER') == '') {
    return '';
  }
  var port = get_env('DEPLOY_PORT');
  if (port != '') {
    port = ' -p' + port.substring(1, port.length);
  }

  return 'ssh ' + get_env('DEPLOY_USER') + '@' + get_env('DEPLOY_SERVER') + port;
}

action_env(basePath) async {
  require_site_root(basePath);

  print("Site root:\n\t$basePath\n");

  var connStr = ftp_conn_str();
  if (connStr != '') {
    print("FTP:\n\t" + connStr);
    print('');
  }

  connStr = get_ssh_command();
  if (connStr != '') {
    print('SSH:');
    print("\t" + connStr);
    print("\t" + quote_args(ssh_exec_remote()));
    print('');
  }

  print('ENV config:');
  for (final k in ENV_LOCAL.keys) {
    print("\t" + k + " -> " + ENV_LOCAL[k]);
  }
  print('');
}

action_db(basePath) async {
  require_site_root(basePath);
  await require_command('xdg-open');

  var url = '';
  var siteUrl = get_env('APP_URL');
  if (siteUrl != '') {
    url = siteUrl;
  } else {
    //TODO http or https from settings
    url = 'http://' + get_site_host(basePath) + '/';
  }
  url += 'adminer/?username=' +
      get_env('DB_USERNAME') +
      '&db=' +
      get_env('DB_DATABASE') +
      '&password=' +
      get_env('DB_PASSWORD');

  return run('xdg-open', [url]);
}

action_ftp(basePath) async {
  require_site_root(basePath);
  await require_command('filezilla');

  var connStr = ftp_conn_str();

  if (is_mingw() || is_wsl()) {
    return start('filezilla', [connStr, '--local=' + basePath]);
  } else if (await is_ubuntu()) {
    await require_command('screen');
    return run('screen', ['-d', '-m', 'filezilla', connStr, '--local=' + basePath]);
  }
  //else {
  	// run('filezilla', connStr, '--local=' + basePath, &> /dev/null &)';
  //}
}

action_ssh(basePath) async {
  require_site_root(basePath);
  await require_command('ssh');
  await require_command('sshpass');

  var remoteCommand = new List.from(ARGV);
  remoteCommand.removeAt(0);
  var args = ssh_exec_remote(remoteCommand.join(' '));
  var cmd = args.first;
  args.removeAt(0);

  await runInteractive(cmd, args);
}

action_ssh_test(basePath) async {
  require_site_root(basePath);
  await require_command('ssh');
  await runInteractive(get_ssh_command(), new List<String>.from([]));
}

get_bitrix_modules_path(basePath) {
  return get_public_path(basePath) + '/bitrix/modules/';
}

git_repos_map(basePath) {
  var pathModules = get_bitrix_modules_path(basePath);
  var solutionRepos = get_env('SOLUTION_GIT_REPOS').split("\n");
  if (!Directory(pathModules).existsSync()) {
    solutionRepos = [];
    var content = new Directory(basePath).listSync();
    for (final f in content) {
      if (f is Directory) {
        solutionRepos.add(f.path + ';master;/' + p.basename(f.path));
      }
    }
  }
  var result = {};
  for (final line in solutionRepos) {
    if (line.trim() == '') {
      continue;
    }
    var tmp = line.split(SOLUTION_REPOS_SEP);
    var url = tmp[0].trim();
    var moduleId = p.basenameWithoutExtension(url);
    var branch = (tmp.length > 1) ? tmp[1].trim() : 'master';
    var path = (tmp.length > 2) ?
      (get_public_path(basePath) + tmp[2].trim())
      : (pathModules + p.basenameWithoutExtension(url));
    var page = (tmp.length > 3) ? tmp[3].trim() : '';
    //TODO!!! названия директории в moduleId теперь могут совпадать - переделать result на массив
    result[moduleId] = [page, url, branch, path];
  }

  return result;
}

git_clone(String basePath, String moduleId, String urlRepo, String branch, String path) async {
  if (Directory(path).existsSync()) {
    await runInteractive('rm', ['-Rf', path]);
  }
  await runInteractive('git', ['clone', urlRepo, path]);
  if (Directory(path).existsSync()) {
    chdir(path);
    await runInteractive('git', ['config', 'core.fileMode', 'false']);
    await runInteractive('git', ['checkout', branch]);
    await runInteractive('git', ['config', '--global', '--add', 'safe.directory', path]);
  }
}

fetch_repos(basePath) async {
  var solutionRepos = git_repos_map(basePath);
  if (solutionRepos.keys.length == 0) {
    return;
  }

  var pathModules = get_bitrix_modules_path(basePath);
  if (!Directory(pathModules).existsSync()) {
    new Directory(pathModules).createSync(recursive: true);
  }

  print('Repositories info:');
  for (final moduleId in solutionRepos.keys) {
    var repoInfo = solutionRepos[moduleId];
    var page = repoInfo[0];
    var url = repoInfo[1];
    var branch = repoInfo[2];
    var path = repoInfo[3];
    print(moduleId + ' [$branch]');
    print("\t$url");
    print("\t\t-> $path\n");
  }
  if (!confirm_continue('Warning! Modules will be removed.')) {
    exit(0);
  }
  for (final moduleId in solutionRepos.keys) {
    var repoInfo = solutionRepos[moduleId];
    var page = repoInfo[0];
    var url = repoInfo[1];
    var branch = repoInfo[2];
    var path = repoInfo[3];
    print('Fetch repo ' + url + ' ...');
    await git_clone(basePath, moduleId, url, branch, path);
    print('');
  }
}

action_status(basePath) async {
  require_site_root(basePath);

  var solutionRepos = git_repos_map(basePath);
  if (solutionRepos.keys.length == 0) {
    return;
  }

  for (final moduleId in solutionRepos.keys) {
    var repoInfo = solutionRepos[moduleId];
    var page = repoInfo[0];
    var url = repoInfo[1];
    var branch = repoInfo[2];
    var path = repoInfo[3];

    if (!Directory(path).existsSync()) {
      print("Directory '$path' for '$url' not exists");
      continue;
    }
    chdir(path);
    if (!Directory(path + '/.git/').existsSync()) {
      continue;
    }
    await runInteractive('pwd', []);
    await runInteractive('git', ['status']);
    await runInteractive('git', ['branch']);
    print('');
  }
}

action_pull(basePath) async {
  require_site_root(basePath);

  var solutionRepos = git_repos_map(basePath);
  if (solutionRepos.keys.length == 0) {
    return;
  }

  for (final moduleId in solutionRepos.keys) {
    var repoInfo = solutionRepos[moduleId];
    var page = repoInfo[0];
    var url = repoInfo[1];
    var branch = repoInfo[2];
    var path = repoInfo[3];

    if (!Directory(path).existsSync()) {
      print("Directory '$path' for '$url' not exists");
      continue;
    }
    chdir(path);
    if (!Directory(path + '/.git/').existsSync()) {
      continue;
    }
    await runInteractive('pwd', []);
    await runInteractive('git', ['pull']);
    print('');
  }
}

action_reset(basePath) async {
  require_site_root(basePath);

  var solutionRepos = git_repos_map(basePath);
  if (solutionRepos.keys.length == 0) {
    return;
  }

  if (!confirm_continue('Warning! All file changes will be removed.')) {
    exit(0);
  }

  for (final moduleId in solutionRepos.keys) {
    var repoInfo = solutionRepos[moduleId];
    var page = repoInfo[0];
    var url = repoInfo[1];
    var branch = repoInfo[2];
    var path = repoInfo[3];

  if (!Directory(path).existsSync()) {
      print("Directory '$path' for '$url' not exists");
      continue;
    }
    chdir(path);
    if (!Directory(path + '/.git/').existsSync()) {
      continue;
    }
    await runInteractive('pwd', []);
    await runInteractive('git', ['reset', '--hard', 'HEAD']);
    print('');
  }
}

action_push(basePath) async {
  require_site_root(basePath);

  var solutionRepos = git_repos_map(basePath);
  if (solutionRepos.keys.length == 0) {
    return;
  }

  if (!confirm_continue('Warning! All file changes will be pushed.')) {
    exit(0);
  }

  for (final moduleId in solutionRepos.keys) {
    var repoInfo = solutionRepos[moduleId];
    var page = repoInfo[0];
    var url = repoInfo[1];
    var branch = repoInfo[2];
    var path = repoInfo[3];

  if (!Directory(path).existsSync()) {
      print("Directory '$path' for '$url' not exists");
      continue;
    }
    chdir(path);
    if (!Directory(path + '/.git/').existsSync()) {
      continue;
    }
    await runInteractive('pwd', []);
    await runInteractive('git', ['add', '.']);
    await runInteractive('git', ['commit', '-am', DateTime.now().toString()]);
    await runInteractive('git', ['push']);
    print('');
  }
}

action_checkout(basePath) async {
  require_site_root(basePath);

  var solutionRepos = git_repos_map(basePath);
  if (solutionRepos.keys.length == 0) {
    return;
  }

  for (final moduleId in solutionRepos.keys) {
    var repoInfo = solutionRepos[moduleId];
    var page = repoInfo[0];
    var url = repoInfo[1];
    var branch = repoInfo[2];
    var path = repoInfo[3];

    if (!Directory(path).existsSync()) {
      print("Directory '$path' for '$url' not exists");
      continue;
    }
    chdir(path);
    if (!Directory(path + '/.git/').existsSync()) {
      continue;
    }
    await runInteractive('pwd', []);
    await runInteractive('git', ['checkout', branch]);
    print('');
  }
}

action_fixdir(basePath) async {
  require_site_root(basePath);

  if (await is_ubuntu()) {
    var dirUser = get_env('SITE_DIR_USER');
    if (dirUser != '') {
      await sudo_run('chown', ['-R', dirUser, basePath]);
    }
    var dirRights = get_env('SITE_DIR_RIGHTS');
    if (dirRights != '') {
      await sudo_run('chmod', ['-R', dirRights, basePath]);
    }
  }
}

download_node(srcUrl, path, nodeDir) async {
  var extension = p.extension(srcUrl, 2);
  var outputFile = path + '/node.tmp' + extension;
  if (File(outputFile).existsSync()) {
    File(outputFile).deleteSync();
  }
  var nodePath = path + '/' + nodeDir;
  if (Directory(nodePath).existsSync()) {
    print('Remove ' + nodePath + ' ...');
    new Directory(nodePath).deleteSync(recursive: true);
  }
  print("Loading $srcUrl ...");
  await request_get(srcUrl, outputFile);
  if (!File(outputFile).existsSync()) {
    die('Error on loading nodejs from ' + srcUrl);
  }
  chdir(path);
  print('Extracting files ...');
  await any_archive_extract(outputFile, './');
  if (File(outputFile).existsSync()) {
    File(outputFile).deleteSync();
  }
  var extractedDirName = p.basenameWithoutExtension(srcUrl);
  if (p.extension(extractedDirName) == '.tar') {
    extractedDirName = p.basenameWithoutExtension(extractedDirName);
  }
  var srcNodePath = path + '/' + extractedDirName;
  if (!Directory(srcNodePath).existsSync()) {
    die('Extracted nodejs folder [' + srcNodePath + '] not found.');
  }
  Directory(srcNodePath).renameSync(nodePath);
}

node_path(cmd, [prefix = '']) {
  var path = get_home() + '/bin/node' + prefix;
  if (!Directory(path).existsSync()) {
    die('Nodejs directory [' + path + '] - not exists.');
  }
  if (!Platform.isWindows) {
    // set PATH temporarily for node
    ENV_LOCAL['PATH'] = path + '/bin' + ENV_PATH_SEP + PATH_ORIGINAL;
    path += '/bin/' + cmd;
  } else {
    // set PATH temporarily for node
    ENV_LOCAL['PATH'] = path + ENV_PATH_SEP + PATH_ORIGINAL;
    path += '/' + cmd + '.cmd';
  }

  return path;
}

node_path_bitrix(cmd) {
  return node_path(cmd, '_bitrix');
}

action_js_install([basePath = '']) async {
  var path = get_home() + '/bin';

  if (!Directory(path).existsSync()) {
    new Directory(path).createSync(recursive: true);
  }

  var srcUrl = '';
  print('Download nodejs LTS');
  if (Platform.isLinux) {
    srcUrl = get_env('NODE_URLS_LINUX');
  } else if (Platform.isMacOS) {
    srcUrl = get_env('NODE_URLS_MACOS');
  } else if (Platform.isWindows) {
    if (is_windows_32bit()) {
      srcUrl = get_env('NODE_URLS_WIN32');
    } else {
      srcUrl = get_env('NODE_URLS_WIN64');
    }
  }
  if (srcUrl != '') {
    await download_node(srcUrl, path, 'node');
  }

  // https://nodejs.org/en/blog/release/v9.11.2/
  // https://nodejs.org/dist/v9.11.2/
  srcUrl = '';
  print('Download nodejs for Bitrix');
  if (Platform.isLinux) {
    srcUrl = get_env('NODE_URLS_BITRIX_LINUX');
  } else if (Platform.isMacOS) {
    srcUrl = get_env('NODE_URLS_BITRIX_MACOS');
  } else if (Platform.isWindows) {
    if (is_windows_32bit()) {
      srcUrl = get_env('NODE_URLS_BITRIX_WIN32');
    } else {
      srcUrl = get_env('NODE_URLS_BITRIX_WIN64');
    }
  }
  if (srcUrl != '') {
    await download_node(srcUrl, path, 'node_bitrix');
  }

  print('Install bitrixcli ...');
  await run(node_path_bitrix('npm'), ['install', '-g', '@bitrix/cli'], true);

  print('Install google-closure-compiler, esbuild ...');
  await run(node_path('npm'), ['install', '-g', 'google-closure-compiler'], true);
  // https://esbuild.github.io/getting-started/#download-a-build
  await run(node_path('npm'), ['install', '-g', 'esbuild'], true);
}

get_public_path(basePath) {
  var prefix = get_env('DIR_PUBLIC');
  if (prefix.endsWith('/')) {
    prefix = prefix.substring(0, prefix.length - 1);
  }

  return basePath + prefix;
}

get_sites_root() {
  var result = get_env('DIR_LOCAL_SITES');
  if (result.startsWith('~/')) {
    return get_home() + '/' + result.substring(2, result.length);
  }

  return result;
}

action_solution_init(basePath) async {
  require_site_root(basePath);

  var solution = (ARGV.length > 1) ? ARGV[1] : '';
  var solutionConfigPath = get_home() + '/bin/.dev/solution.env.settings/' + solution + '/example.env';
  if (solution != '') {
    if (!File(solutionConfigPath).existsSync()) {
      die("Config for solution [$solution] not defined.");
    }
    var siteConfig = basePath + '/' + BASE_ENV_NAME;
    var originalContent = file_get_contents(siteConfig);
    var content = file_get_contents(solutionConfigPath);
    if (originalContent.indexOf(content) < 0) {
      content = originalContent + "\n" + content + "\n";
      file_put_contents(siteConfig, content);
    }
    ENV_LOCAL = await load_env(siteConfig);
  }
  await fetch_repos(basePath);

  //TODO!!! добавлять в .gitignore в корне сайта список путей для каждого репозитария
}

action_solution_reset(basePath) async {
  require_site_root(basePath);

  if (!confirm_continue('Warning! Site public data will be removed.')) {
    exit(0);
  }

  await action_fixdir(basePath);
  await run_php([
    REAL_BIN + '/.action_solution_reset.php',
    get_public_path(basePath),
  ]);
}

//TODO!!! use native conv
action_conv_win([basePath = '']) async {
  return run_php([REAL_BIN + '/.action_conv.php', 'win']);
}

//TODO!!! use native conv
action_conv_utf([basePath = '']) async {
  var args = [REAL_BIN + '/.action_conv.php', 'utf'];
  if (basePath != '') {
    args.add(get_public_path(basePath));
  }

  return run_php(args);
}

action_solution_conv_utf(basePath) async {
  require_site_root(basePath);

  var solutionRepos = git_repos_map(basePath);
  if (solutionRepos.keys.length == 0) {
    return;
  }

  for (final moduleId in solutionRepos.keys) {
    var repoInfo = solutionRepos[moduleId];
    var page = repoInfo[0];
    var url = repoInfo[1];
    var branch = repoInfo[2];
    var path = repoInfo[3];

    if (!Directory(path).existsSync()) {
      print("Directory '$path' for '$url' not exists");
      continue;
    }
    chdir(path);
    await runInteractive('pwd', []);
    await action_conv_utf();
    print('');
  }
}

/*
action_site_links(basePath) async {
  //TODO??? реализовать создание ссылок как в citrus.wizards
  // install/wizards/ * /site/templates, install/wizards/ * /site/templates_common
  // example for cmd: mklink /D "path to newlink" "path to module folder"
  //NOTE **deprecated** создает симлинки в local - использовать при разработке для сборки через bitrixcli с зависимостями
  require_site_root(basePath);

  var srcSymlinkDirs = [
    'install/js',
    'install/components',
    'install/templates',
    //TODO!!!
    //'install/wizards',
    //'install/admin',
    //'install/tools',
    //'install/gadgets',
    //'install/services',
    //'install/css',
    //'install/themes'
  ];
  var path = getcwd();
  for (final dir in srcSymlinkDirs) {
    var srcDir = path + '/' + dir;
    if (!Directory(srcDir).existsSync()) {
      continue;
    }

    print('Symlinks for ' + srcDir);
    var contents = new Directory(srcDir).listSync();
    for (var f in contents) {
      if (f is Directory) {
        var relPath = p.basename(dir) + '/' + p.basename(f.path);
        var dest = basePath + '/local/' + relPath;
        if (!Directory(dest).existsSync()) {
          Directory(dest).createSync(recursive: true);
        }

        var contentsForSymlinks = new Directory(f.path).listSync();
        for (var v in contentsForSymlinks) {
          if (v is Directory) {
            var destSymlinkDir = dest + '/' + p.basename(v.path);
            print('  ' + relPath + '/' + p.basename(v.path) + ' -> ' + destSymlinkDir);
            if (Link(destSymlinkDir).existsSync()) {
              Link(destSymlinkDir).deleteSync();
            }
            Link(destSymlinkDir).createSync(v.path);
          }
        }
      }
    }
  }
}
*/

action_mod_pack([basePath = '']) async {
  return run_php([REAL_BIN + '/.action_conv.php', 'modpack']);
}

action_mod_update([basePath = '']) async {
  var path = getcwd();
  var module = p.basename(path);
  var solutionRepos = git_repos_map(basePath);
  //TODO!!! переделать на поиск по массиву = проверять на директторию /bitrix/modules/
  var solutionUrl = solutionRepos.containsKey(module) ? solutionRepos[module][0] : '';
  var refresh = ((ARGV.length > 1) && (ARGV[1] == 'refresh')) ? ARGV[1] : '';
  return run_php([REAL_BIN + '/.action_mod_update.php', solutionUrl, refresh]);
}

action_start([basePath = '']) async {
  if (await is_ubuntu()) {
    await service('apache2', 'start');
    await service('mysql', 'start');
    if (await check_command('rinetd')) {
      await sudo_run('service', ['rinetd', 'restart']);
    }
  } else {
    await service('httpd.service', 'start');
    await service('mysqld.service', 'start');
  }
}

action_stop([basePath = '']) async {
  if (await is_ubuntu()) {
    await service('apache2', 'stop');
    await service('mysql', 'stop');
    if (await check_command('rinetd')) {
      await sudo_run('service', ['rinetd', 'stop']);
    }
  } else {
    await service('httpd.service', 'stop');
    await service('mysqld.service', 'stop');
  }
}

action_bitrixcli_build([basePath = '']) async {
  await runInteractive(node_path_bitrix('bitrix'), ['build']);
}

removeEmptyDirs(basePath, path) {
  var dir = p.dirname(path);
  while (dir != basePath) {
    var d = Directory(dir);
    if (d.listSync().length == 0) {
      d.deleteSync();
    } else {
      break;
    }
    dir = p.dirname(dir);
  }
}

action_bitrixcli_build_deps(basePath) async {
  require_site_root(basePath);

  var bitrixPath = get_public_path(basePath) + '/bitrix';
  var path = getcwd();

  var pathParts = {
    '/bitrix/js/': '/js/',
    '/install/js/': '/js/',
    '/local/js/': '/js/',
    '/bitrix/components/': '/components/',
    '/install/components/': '/components/',
    '/install/templates/': '/templates/',
    '/local/components/': '/components/',
  };
  var tmp = [];
  var detectedPart;
  for (final part in pathParts.keys) {
    tmp = path.split(part);
    if (tmp.length != 1) {
      bitrixPath = get_public_path(basePath) + '/local';
      detectedPart = pathParts[part];
      break;
    }
  }

  var destPath = '';
  if (bitrixPath != (get_public_path(basePath) + '/local')) {
    die('Extensions or component should be located in /local/... site folder.');
  }
  if (tmp.length > 1) {
    destPath = bitrixPath + detectedPart + tmp[1];

    var tmpSymLink = false;
    if (!Directory(destPath).existsSync()) {
      tmpSymLink = true;
      Directory(p.dirname(destPath)).createSync(recursive: true);
      Link(destPath).createSync(path);
    }

    await run(node_path_bitrix('bitrix'), ['build', '--path', destPath], true);

    if (tmpSymLink && Link(destPath).existsSync()) {
      Link(destPath).deleteSync();
      removeEmptyDirs(get_public_path(basePath), destPath);
    }
  }
}

action_bitrixcli_create([basePath = '']) async {
  await runInteractive(node_path_bitrix('bitrix'), ['create']);
}

action_bitrixcli_help([basePath = '']) async {
  await runInteractive(node_path_bitrix('bitrix'), ['--help']);
}

action_iblock_parse([basePath = '']) async {
  if (ARGV.length != 2) {
    return;
  }

  final doc = xml.parse(file_get_contents_win(ARGV[1]));
  var iblock = doc.findElements('КоммерческаяИнформация').first.findElements('Классификатор').first;
  for (var prop in iblock.findElements('Свойства').first.findElements('Свойство')) {
    print(prop);
    print("\n---\n");
  }
}

action_site_reset(basePath) async {
  require_site_root(basePath);

  if (!confirm_continue('Warning! Site db tables and files will be removed.')) {
    exit(0);
  }

  await action_fixdir(basePath);
  await run_php([
    REAL_BIN + '/.action_site_reset.php',
    get_public_path(basePath),
  ]);
}

action_site_remove(basePath) async {
  require_site_root(basePath);

  await action_site_reset(basePath);

  if (await is_ubuntu()) {
    var path = getcwd();

    // remove site
    var sitehost = get_site_host(path);
    var destpath = '/etc/apache2/sites-available/' + sitehost + '.conf';
    await sudo_run('a2dissite', [sitehost + '.conf']);
    await sudo_run('rm', [destpath]);
    await service('apache2', 'reload');

    // remove db
    var dbpassword = get_env('DB_PASSWORD');
    var dbname = get_env('DB_DATABASE');
    var dbconf = REAL_BIN + '/.template/ubuntu18.04/dbdrop.sql';
    var sqlContent = file_get_contents(dbconf);
    sqlContent = sqlContent
        .replaceAll('bitrixdb1', dbname)
        .replaceAll('bitrixuser1', dbname)
        .replaceAll('bitrixpassword1', dbpassword);
    dbconf = path + '/.dbdrop.tmp.sql';
    file_put_contents(dbconf, sqlContent);
    // TODO!!! using pipes for run() / sudo_run()
    // TODO!!! use mysql from dart https://github.com/adamlofts/mysql1_dart
    await system("sudo mysql -u root < '$dbconf'");
    File(dbconf).deleteSync();
  }
}

action_site_hosts([basePath = '']) async {
  var path = basePath;
  var localIp = '127.0.0.1';
  var localIpDup = '::1';
  var sitehost = get_site_host(path);

  var hosts = file_get_contents('/etc/hosts').split("\n");
  var newHosts = [];
  for (final line in hosts) {
    if (line.indexOf(sitehost) < 0) {
      newHosts.add(line);
    }
  }

  print('ADD to config:');
  print('');
  var line = localIp + "\t" + sitehost;
  print(line);
  newHosts.add(line);
  line = localIpDup + "\t" + sitehost;
  print(line);
  newHosts.add(line);

  var tmp = path + '/.hosts.tmp';
  file_put_contents(tmp, newHosts.join("\n") + "\n");
  await sudo_run('mv', [tmp, '/etc/hosts']);

  print('');
  print('NOTE: for WSL add lines to "%systemroot%\\system32\\drivers\\etc\\hosts" manually');
}

get_site_config(sitehost) {
  return '/etc/apache2/sites-available/' + sitehost + '.conf';
}

require_site_config(sitehost) {
  var destpath = get_site_config(sitehost);
  if (!File(destpath).existsSync()) {
    die("Config for site $sitehost not exists.");
  }
}

patch_site_config(path, destpath, originalContent) async {
  print('');
  print('# Apache2 site config -> ' + destpath);
  print('');
  print(originalContent);

  var tmp = path + '/.newsiteconfig.tmp';
  file_put_contents(tmp, originalContent);
  await sudo_run('mv', [tmp, destpath]);
  await service('apache2', 'reload');
}

action_site_proxy([basePath = '']) async {
  if (await is_ubuntu()) {
    var path = basePath;
    var sitehost = get_site_host(path);
    require_site_config(sitehost);

    var destpath = get_site_config(sitehost);
    var ip = (ARGV.length > 1) ? ARGV[1] : 'remove';
    var originalContent = file_get_contents(destpath);
    var content = "\n";
    if ((ip != '') && (ip != 'remove')) {
      content = """

ProxyPreserveHost On
ProxyPass        /  http://$ip/
ProxyPassReverse /  http://$ip/
""";
    }
    var re = new RegExp(
      r"\#bx\-proxy\s+start.+?\#bx\-proxy\s+end",
      caseSensitive: false,
      multiLine: false,
      dotAll: true,
    );
    if (re.hasMatch(originalContent)) {
      originalContent = originalContent.replaceFirst(re, "#bx-proxy start$content#bx-proxy end");
    } else {
      originalContent =
          originalContent.replaceFirst('</VirtualHost>', "\n#bx-proxy start$content#bx-proxy end\n\n</VirtualHost>");
    }

    patch_site_config(path, destpath, originalContent);
  }
}

action_site_https([basePath = '']) async {
  if (await is_ubuntu()) {
    var path = basePath;
    var sitehost = get_site_host(path);
    require_site_config(sitehost);

    var certKeyName = get_env('BX_MKCERT');
    if (certKeyName == '') {
      certKeyName = 'bx.local *.bx.local';
    }
    var tmp = certKeyName.split(' ');
    certKeyName = tmp[0];

    var destpath = get_site_config(sitehost);
    var action = (ARGV.length > 1) ? ARGV[1] : 'on'; // on | off
    var originalContent = file_get_contents(destpath);

    var sslPath = get_home() + '/.ssl/' + certKeyName + '+' + (tmp.length - 1).toString();
    var sslCertPath = "SSLCertificateFile $sslPath.pem";
    var sslCertKeyPath = "SSLCertificateKeyFile $sslPath-key.pem";
    if (action == 'on') {
      var sslContent = """
        SSLEngine on
        $sslCertPath
        $sslCertKeyPath
      """;
      originalContent = originalContent
        .replaceFirst('<VirtualHost *:80>', "<IfModule mod_ssl.c>\n<VirtualHost *:443>")
        .replaceFirst('</VirtualHost>', sslContent + "\n</VirtualHost>\n</IfModule>");
    } else if (action == 'off') {
      originalContent = originalContent
        .replaceFirst('<VirtualHost *:443>', "<VirtualHost *:80>")
        .replaceFirst('SSLEngine on', '')
        .replaceFirst(sslCertPath, '')
        .replaceFirst(sslCertKeyPath, '')
        .replaceFirst('<IfModule mod_ssl.c>', '')
        .replaceFirst('</IfModule>', '');
    }

    patch_site_config(path, destpath, originalContent);
  }
}

skip_file(path) {
  if ((path.indexOf('/.dev/') >= 0) || (path.indexOf('/.git/') >= 0)) {
    return true;
  }
  return false;
}

action_es9(basePath) async {
  var compilerPath = node_path('google-closure-compiler');
  if ((ARGV.length != 2) || !(ARGV[1] == 'all')) {
    basePath = getcwd();
  }
  final dir = new Directory(basePath);
  dir.list(recursive: true, followLinks: true).listen((FileSystemEntity entity) async {
    if ((entity is Directory) || skip_file(entity.path)) {
      return;
    }
    var f = entity.path;
    var type = f.substring(f.length - 7);
    if (type == '.min.js') {
      return;
    }

    var extraParams = [];
    var destFile = f;
    var es9 = false;
    if ((type == '.es9.js') || (type == '.es6.js')) {
      destFile = destFile.replaceAll('.es9.js', '.min.js').replaceAll('.es6.js', '.min.js');
      extraParams = ['--language_in', 'ECMASCRIPT_2018', '--language_out', 'ECMASCRIPT5_STRICT'];
      es9 = true;
    } else if ((f.substring(f.length - 3) == '.js')) {
      destFile = destFile.replaceAll('.js', '.min.js');
    } else {
      return;
    }

    if (!is_bx_debug()) {
      print('Processing ' + f + ' -> ' + p.basename(destFile));
    }
    if (es9) {
      //TODO!!! как передавать пути к модулям
      await action_conv_utf(f);
      var res = await run(compilerPath, ['--js', f, '--js_output_file', destFile, ...extraParams]);
      if ((res == 0) && File(destFile).existsSync()) {
        var srcFile = destFile;
        destFile = destFile.replaceAll('.min.js', '.js');
        File(srcFile).copySync(destFile);
      }
    } else {
      File(f).copySync(destFile);
    }
  });
}

action_minify(basePath) async {
  var toolPath = node_path('esbuild');
  if ((ARGV.length != 2) || !(ARGV[1] == 'all')) {
    basePath = getcwd();
  }
  final dir = new Directory(basePath);
  dir.list(recursive: true, followLinks: true).listen((FileSystemEntity entity) async {
    if ((entity is Directory) || skip_file(entity.path)) {
      return;
    }
    var f = entity.path;
    if ((f.substring(f.length - 7) == '.min.js') || (f.substring(f.length - 8) == '.min.css')) {
      return;
    }

    var destFile = f;
    var is_css = false;
    if (f.substring(f.length - 3) == '.js') {
      destFile = destFile.replaceAll('.js', '.min.js');
    } else if (f.substring(f.length - 4) == '.css') {
      destFile = destFile.replaceAll('.css', '.min.css');
      is_css = true;
    } else {
      return;
    }

    if (!is_bx_debug()) {
      print('Processing ' + f + ' -> ' + p.basename(destFile));
    }

    var toolArgs = [];
    if (is_css) {
      toolArgs.add('--loader=css');
    }
    toolArgs.add('--minify');
    await action_conv_utf(f);
    var args = toolArgs.join(' ');
    await system("cat '$f' | $toolPath $args > '$destFile'");
  });
}

void copyDirectorySync(Directory source, Directory destination, [filter = null]) {
  source.listSync(recursive: false).forEach((var entity) {
    if (entity is Directory) {
      var newDirectory = Directory(p.join(destination.absolute.path, p.basename(entity.path)));
      newDirectory.createSync();

      copyDirectorySync(entity.absolute, newDirectory, filter);
    } else if (entity is File) {
      if ((filter != null) && !filter(entity.path)) {
        return;
      }
      entity.copySync(p.join(destination.path, p.basename(entity.path)));
    }
  });
}

void processDirectorySync(Directory source, filter) {
  source.listSync(recursive: false).forEach((var entity) {
    if (entity is Directory) {
      processDirectorySync(entity.absolute, filter);
    } else if (entity is File) {
      if (filter != null) {
        filter(entity.path);
      }
    }
  });
}

add_database(path, dbconf, dbname, dbpassword) async {
  dbconf = REAL_BIN + '/.template/ubuntu18.04/' + dbconf;
  var sqlContent = file_get_contents(dbconf);
  sqlContent = sqlContent
      .replaceAll('bitrixdb1', dbname)
      .replaceAll('bitrixuser1', dbname)
      .replaceAll('bitrixpassword1', dbpassword);
  dbconf = path + '/.dbcreate.tmp.sql';
  file_put_contents(dbconf, sqlContent);
  await system("sudo mysql -u root < '$dbconf'");
  File(dbconf).deleteSync();
}

add_site(path, sitehost, siteconf) async {
  var publicPath = get_public_path(path);

  var currentUser = get_user();
  siteconf = REAL_BIN + '/.template/ubuntu18.04/' + siteconf;
  var content = file_get_contents(siteconf);
  content = content
      .replaceAll('/home/user/ext_www/bitrix-site.com', publicPath)
      .replaceAll('bitrix-site.com', sitehost)
      .replaceAll('/home/user/.ssl/', "/home/$currentUser/.ssl/");
  siteconf = path + '/.apache2.conf.tmp';
  file_put_contents(siteconf, content);

  var destpath = '/etc/apache2/sites-available/' + sitehost + '.conf';
  print('');
  print('# Apache2 site config -> ' + destpath);
  print('');
  print(content);
  await sudo_run('mv', [siteconf, destpath]);
  await sudo_run('a2ensite', [sitehost + '.conf']);
  await service('apache2', 'reload');
}

action_php(basePath) async {
  var args = new List.from(ARGV);
  args.removeAt(0);
  await run_php(args);
}

action_vscode_sftp(basePath) async {
  //TODO!!! create .vscode/sftp.json from env
}

action_site_init(basePath) async {
  var site_root = basePath;
  var site_exists = (site_root != '') && (get_env('SITE_ENCODING') != '');
  var path = getcwd();
  var encoding = (ARGV.length > 1) ? ARGV[1] : 'win'; // win | utf | utflegacy
  var sitehost = get_site_host(path);

  if (await is_ubuntu()) {
    await action_fixdir(basePath);
    var dbpassword = random_password();
    var dbname = random_name();

    if (site_exists) {
      encoding = get_env('SITE_ENCODING');
      dbpassword = get_env('DB_PASSWORD');
      dbname = get_env('DB_DATABASE');
      path = site_root;
      sitehost = get_site_host(path);
    } else {
      var siteconf = '';
      var dbconf = '';
      if (encoding == 'win') {
        siteconf = 'win1251site.conf';
        dbconf = 'win1251dbcreate.sql';
      } else if (encoding == 'utflegacy') {
        siteconf = 'utf8legacysite.conf';
        dbconf = 'utf8dbcreate.sql';
        encoding = 'utf';
      } else {
        siteconf = 'utf8site.conf';
        dbconf = 'utf8dbcreate.sql';
        encoding = 'utf';
      }

      // init site conf files
      site_root = path;
      add_database(path, dbconf, dbname, dbpassword);
      add_site(path, sitehost, siteconf);
    }

    filterExistingFiles(path) {
      if (!site_exists) {
        return true;
      }

      if (path.indexOf('/.template/www/' + BASE_ENV_NAME) > 0) {
        return false;
      }

      return true;
    }

    var templatePath = REAL_BIN + '/' + '.template/www';
    copyDirectorySync(Directory(templatePath), Directory(path), filterExistingFiles);
    if (encoding != 'win') {
      copyDirectorySync(Directory(templatePath + '_' + encoding), Directory(path), filterExistingFiles);
    }

    if (!is_mingw()) {
      //TODO!!! поправить в конфигах .template - указать стандартные параметры БД для localwp
      replaceConfigValues(fname) {
        if ((fname.indexOf('/adminer/') > 0)
        	|| (fname.indexOf('/local/modules/') > 0)) {
          return;
        }
        var envContent = file_get_contents(fname);
        envContent = envContent
            .replaceAll('dbname1', dbname)
            .replaceAll('dbuser1', dbname)
            .replaceAll('dbpassword12345', dbpassword)
            .replaceAll('111encoding111', encoding)
            .replaceAll('http://bitrixsolution01.example.org/', 'https://' + sitehost + '/');
        file_put_contents(fname, envContent);
      }

      processDirectorySync(Directory(path), replaceConfigValues);
    }

    // поправить права
    ENV_LOCAL = await load_env(site_root + '/' + BASE_ENV_NAME);
    await action_fixdir(site_root);
  }
}

void main(List<String> args) async {
  ARGV = args;
  var site_root = detect_site_root('');
  if (site_root == '') {
    site_root = detect_site_root('', false);
  }
  ENV_LOCAL = await load_env(site_root + '/' + BASE_ENV_NAME);

  var actions = {
    // bitrix
    'help': action_help,
    'fetch': action_fetch,

    // site
    'env': action_env,
    'ftp': action_ftp,
    'ssh': action_ssh,
    'ssh-test': action_ssh_test,
    'db': action_db,
    'fixdir': action_fixdir,
    'php': action_php,
    'vscode-sftp': action_vscode_sftp,

    // git
    'status': action_status,
    'pull': action_pull,
    'reset': action_reset,
    //'push': action_push,
    'checkout': action_checkout,

    // solution
    'solution-init': action_solution_init,
    'solution-reset': action_solution_reset,
    'solution-conv-utf': action_solution_conv_utf,
    'conv-win': action_conv_win,
    'conv-utf': action_conv_utf,
    'mod-pack': action_mod_pack,
    'mod-update': action_mod_update,
    'site-init': action_site_init,
    'site-reset': action_site_reset,
    'site-remove': action_site_remove,
    'site-hosts': action_site_hosts,
    'site-proxy': action_site_proxy,
    'site-https': action_site_https,
    //'site-links': action_site_links, //TODO!!! create multisite links
    'iblock-parse': action_iblock_parse, //TODO!!!

    // server
    'start': action_start,
    'stop': action_stop,

    // tools
    //TODO!!! 'js': action_js -> bx js some-file.js
    'js-install': action_js_install,
    'es9': action_es9,
    'minify': action_minify,

    // bitrix cli
    // https://dev.1c-bitrix.ru/learning/course/index.php?COURSE_ID=43&LESSON_ID=12435&LESSON_PATH=3913.3516.4776.3635.12435
    'build': action_bitrixcli_build, // 'bitrix build' for single scripts
    'build-deps': action_bitrixcli_build_deps, // 'bitrix build' with deps
    'create': action_bitrixcli_create, // 'bitrix create'
    'help-cli': action_bitrixcli_help, // 'bitrix help'
  };

  var action = '';
  if (ARGV.length == 0) {
    action = 'help';
  } else {
    action = ARGV[0];
  }
  if (!actions.containsKey(action)) {
    action = 'help';
  }
  await actions[action]!(site_root);

  //await run_php(['-i']);
  //await runWithInputFromFile('perl', [], '_test.pl');
}
