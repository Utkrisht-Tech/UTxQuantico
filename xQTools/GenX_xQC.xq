// Tool to regenerate UTxQ's bootstrap .c files
// every time the UTxQuantico's master branch is updated.

// if run with the --serve flag it will run in webhook
// server mode awaiting a request to http://host:port/genhook

// available command line flags:
// --work-dir  GenX_xQC's working directory
// --purge     force purge the local repositories
// --serve     run in webhook server mode
// --port      port for http server to listen on
// --log-to    either 'file' or 'terminal'
// --log-file  path to log file used when --log-to is 'file'
// --dry-run   dont push anything to remote repo

module main

import (
	os
	LogX
	FlagX
	time
	WebX
	NetX.urllib
)

// Git credentials of User
const(
	git_Username = os.getenv('GITUSER')
	git_Password = os.getenv('GITPASS')
)

// Repository
const(
	// Git Repo
	git_Repo_UTxQ  = 'github.com/Utkrisht-Tech/UTxQuantico'
	// git_Repo_X = 'github.com/Utkrisht-Tech/X'
	// Local Repo directories
	git_Repo_dir_UTxQ  = 'UTxQuantico'
	// git_Repo_dir_X = 'X'
)

// GenX_xQC
const(
	// Name
	app_Name = 'GenX_xQC'
	// Version
	app_Version = '0.0.1'
	// Description
	app_Description = 'Tool to regenerate  UTxQ\'s bootstrap .c files every time the UTxQuantico\'s master branch is updated.'
	// File size lower-bound
	too_short_filesize_limit = 5000
	// create a .c file for these os's
	xQC_build_oses = [
		'unix',
		'windows'
	]
)

// Default options (overridden by flags)
const(
	// GenX_xQC working directory
	work_dir = '/tmp/GenX_xQC'
	// Don't push anything to remote repo
	dry_run = false
	// Server port
	server_port = 7171
	// Log file
	log_file = '$work_dir/log.txt'
	// log_to is either 'file' or 'terminal'
	log_to = 'terminal'
)

// errors
const(
	err_msg_build = 'error building'
	err_msg_make  = 'make failed'
	err_msg_GenX_C = 'failed to generate .c file'
	err_msg_cmd_x = 'error running cmd'
)

struct GenXQC {
	// Logger
	logger &LogX.Log
	// Flag options
	options FlagOptions
mut:
	// true if error was experienced running generate
	gen_error bool
}

// Webhook server
struct WebhookServer {
public mut:
	WebX   WebX.Context
	GenX_xQC &GenXQC
}

// Storage for flag options
struct FlagOptions {
	work_dir string
	purge    bool
	serve    bool
	port     int
	log_to   string
	log_file string
	dry_run  bool
}

fn main() {
	mut fp := FlagX.new_FlagX_parser(os.args.clone())

	fp.application(app_Name)
 	fp.version(app_Version)
 	fp.description(app_Description)
 	fp.skip_executable()

	flag_options := parse_flags(mut fp)

 	_ := fp.finalize() or {
 		eprintln(err)
 		println(fp.usage())
 		return
 	}
	// Webhook server mode
	if flag_options.serve {
		WebX.run<WebhookServer>(flag_options.port)
	}
	// cmd mode
	else {
		mut GenX_xQC := new_GenX_xQC(flag_options)
		GenX_xQC.init()
		GenX_xQC.generate()
	}
}

// new GenXQC
fn new_GenX_xQC(flag_options FlagOptions) &GenXQC {
	return &GenXQC{
		// options
		options: flag_options
		// logger
		logger: if flag_options.log_to == 'file' {
			&LogX.Log{LogX.DEBUG, flag_options.log_file}
		} else {
			&LogX.Log{LogX.DEBUG, 'terminal'}
		}
	}
}

// WebhookServer init
public fn (ws mut WebhookServer) init() {
	mut fp := FlagX.new_FlagX_parser(os.args.clone())
	flag_options := parse_flags(mut fp)
	ws.GenX_xQC = new_GenX_xQC(flag_options)
	ws.GenX_xQC.init()
}

// gen webhook
public fn (ws mut WebhookServer) genhook() {
	ws.GenX_xQC.generate()
	// error in generate
	if ws.GenX_xQC.gen_error {
		ws.WebX.json('{status: "failed"}')
		return
	}
	ws.WebX.json('{status: "ok"}')
}

// parse flags to FlagOptions struct
fn parse_flags(fp mut FlagX.FlagXParser) FlagOptions {
	return FlagOptions{
		serve    : fp.bool('serve', false, 'run in webhook server mode')
		work_dir : fp.string('work-dir', work_dir, 'GenX_xQC working directory')
		purge    : fp.bool('purge', false, 'force purge the local repositories')
		port     : fp.int('port', int(server_port), 'port for web server to listen on')
		log_to   : fp.string('log-to', log_to, 'log to is \'file\' or \'terminal\'')
		log_file : fp.string('log_file', log_file, 'log file to use when log-to is \'file\'')
		dry_run  : fp.bool('dry-run', dry_run, 'when specified dont push anything to remote repo')
	}
}

// init
fn (GenX_xQC mut GenXQC) init() {
	// Purge repos if flag is passed
	if GenX_xQC.options.purge {
		GenX_xQC.purge_repos()
	}
}

// Regenerate
fn (GenX_xQC mut GenXQC) generate() {
	// set errors to false
	GenX_xQC.gen_error = false

	// check if GenX_xQC dir exists
	if !os.dir_exists(GenX_xQC.options.work_dir) {
		// try create
		os.mkdir(GenX_xQC.options.work_dir)
		// still dosen't exist... we have a problem
		if !os.dir_exists(GenX_xQC.options.work_dir) {
			GenX_xQC.logger.error('error creating directory: $GenX_xQC.options.work_dir')
			GenX_xQC.gen_error = true
			return
		}
	}

	// cd to GenX_xQC dir
	os.chdir(GenX_xQC.options.work_dir)
	
	// if we are not running with the --serve flag (webhook server)
	// rather than deleting and re-downloading the repo each time
	// first check to see if the local UTxQuantico repo is behind master
	// if it isn't behind theres no point continuing further
	if !GenX_xQC.options.serve && os.dir_exists(git_Repo_dir_UTxQ) {
		GenX_xQC.cmd_exec('git -C $git_Repo_dir_UTxQ checkout master')
		// fetch the remote repo just in case there are newer commits there
		GenX_xQC.cmd_exec('git -C $git_Repo_dir_UTxQ fetch')
		git_Status := GenX_xQC.cmd_exec('git -C $git_Repo_dir_UTxQ status')
		if !git_Status.contains('behind') {
			GenX_xQC.logger.warn('UTxQuantico repository is already up to date.')
			return
		}
	}

	// Delete repos
	GenX_xQC.purge_repos()
	
	// Clone repos
	GenX_xQC.cmd_exec('git clone --depth 1 https://$git_Repo_UTxQ $git_Repo_dir_UTxQ')
	//GenX_xQC.cmd_exec('git clone --depth 1 https://$git_Repo_X $git_Repo_dir_X')
	
	// Get output of git log -1 (last commit)
	git_log_UTxQ := GenX_xQC.cmd_exec('git -C $git_Repo_dir_UTxQ log -1 --format="commit %H%nDate: %ci%nDate Unix: %ct"')
	//git_log_X := GenX_xQC.cmd_exec('git -C $git_Repo_dir_X log -1 --format="Commit %H%nDate: %ci%nDate Unix: %ct"')

	// Date of last commit in each repo
	ts_UTxQ := git_log_UTxQ.find_between('Date:', '\n').trim_space()
	//ts_X := git_log_X.find_between('Date:', '\n').trim_space()
	
	// Parse time as string to time.Time
	last_commit_time_UTxQ  := time.parse(ts_UTxQ)
	//last_commit_time_X := time.parse(ts_X)

	// Git dates are in users local timezone and UTxQ time.parse does not parse
	// timezones at the moment, so for now get unix timestamp from output also
	t_unix_UTxQ := git_log_UTxQ.find_between('Date Unix:', '\n').trim_space().int()
	//t_unix_X := git_log_X.find_between('Date Unix:', '\n').trim_space().int()

	// Last commit hash in UTxQuantico repo
	last_commit_hash_UTxQ := git_log_UTxQ.find_between('commit', '\n').trim_space()
	last_commit_hash_UTxQ_short := last_commit_hash_UTxQ.left(7)

	// Log some info
	GenX_xQC.logger.debug('last commit time ($git_Repo_UTxQ): ' + last_commit_time_UTxQ.format_ss())
	//GenX_xQC.logger.debug('last commit time ($git_Repo_X): ' + last_commit_time_X.format_ss())
	GenX_xQC.logger.debug('last commit hash ($git_Repo_UTxQ): $last_commit_hash_UTxQ')
	
	// If X repo already has a newer commit than the UTxQuantico repo, assume it's up to date
//	if t_unix_X >= t_unix_UTxQ {
//		GenX_xQC.logger.warn('X repository is already up to date.')
//		return
//	}

	// Try build UTxQ for current os (linux in this case)
	GenX_xQC.cmd_exec('make -C $git_Repo_dir_UTxQ')
	xQ_exec := '$git_Repo_dir_UTxQ/UTxQ'
	// Check if make was successful
	GenX_xQC.assert_file_exists_and_is_not_too_short(xQ_exec, err_msg_make)
	
	// build UTxQ.c for each os
    /*
	for os_name in xQC_build_oses {
		xQC_suffix := if os_name == 'unix' { '' } else { '_${os_name.left(3)}' }
		xQ_os_arg := if os_name == 'unix' { '' } else { '-os $os_name' }
		c_file := 'xQ${xQC_suffix}.c'
		// try generate .c file
		GenX_xQC.cmd_exec('$xQ_exec $xQ_os_arg -o $c_file $git_Repo_dir_UTxQ/UTxQCompiler')
		// check if the c file seems ok
		GenX_xQC.assert_file_exists_and_is_not_too_short(c_file, err_msg_GenX_C)
		// embed the latest UTxQ commit hash into the c file
		GenX_xQC.cmd_exec('sed -i \'1s/^/#define UTXQ_COMMIT_HASH "$last_commit_hash_UTxQ_short"\\n/\' $c_file')
		// run clang-format to make the c file more readable
		GenX_xQC.cmd_exec('clang-format -i $c_file')
		// move to X repo
		//GenX_xQC.cmd_exec('mv $c_file $git_Repo_dir_X/$c_file')
		// add new .c file to local X repo
		//GenX_xQC.cmd_exec('git -C $git_Repo_dir_X add $c_file')
	}
    */
	// Check if the X repo actually changed
	/*
    git_Status := GenX_xQC.cmd_exec('git -C $git_Repo_dir_X status') 
	if git_Status.contains('nothing to commit') {
		GenX_xQC.logger.error('No changes to X repo: something went wrong.')
		GenX_xQC.gen_error = true
	}
	// Commit changes to local X repo
	GenX_xQC.cmd_exec_safe('git -C $git_Repo_dir_X commit -m "update from master - $last_commit_hash_UTxQ_short"')
	// Push changes to remote X repo
	GenX_xQC.cmd_exec_safe('git -C $git_Repo_dir_X push https://${urllib.query_escape(git_Username)}:${urllib.query_escape(git_Password)}@$git_Repo_X master')
    */
}

// Only execute when dry_run option is false, otherwise just log
fn (GenX_xQC mut GenXQC) cmd_exec_safe(cmd string) string {
	return GenX_xQC.command_execute(cmd, GenX_xQC.options.dry_run)
}

// Always execute command
fn (GenX_xQC mut GenXQC) cmd_exec(cmd string) string {
	return GenX_xQC.command_execute(cmd, false)
}

// Execute command
fn (GenX_xQC mut GenXQC) command_execute(cmd string, dry bool) string {
	// if dry is true then don't execute, just log
	if dry {
		return GenX_xQC.command_execute_dry(cmd)
	}
	GenX_xQC.logger.info('cmd: $cmd')
	r := os.exec(cmd) or {
		GenX_xQC.logger.error('$err_msg_cmd_x: "$cmd" could not start.')
		GenX_xQC.logger.error( err )
		// Something went wrong, better start fresh next time
		GenX_xQC.purge_repos()
		GenX_xQC.gen_error = true
		return ''
	}
	if r.exit_code != 0 {
		GenX_xQC.logger.error('$err_msg_cmd_x: "$cmd" failed.')
		GenX_xQC.logger.error(r.output)
		// Something went wrong, better start fresh next time
		GenX_xQC.purge_repos()
		GenX_xQC.gen_error = true
		return ''
	}
	return r.output
}

// Just log cmd, don't execute
fn (GenX_xQC mut GenXQC) command_execute_dry(cmd string) string {
	GenX_xQC.logger.info('cmd (dry): "$cmd"')
	return ''
}

// Delete repo directories
fn (GenX_xQC mut GenXQC) purge_repos() {
	// Delete old repos (better to be fully explicit here, since these are destructive operations)
	mut repo_dir := '$GenX_xQC.options.work_dir/$git_Repo_dir_UTxQ'
	if os.dir_exists(repo_dir) {
		GenX_xQC.logger.info('Purging local repo: "$repo_dir"')
		GenX_xQC.cmd_exec('rm -rf $repo_dir')
	}
    /*
	repo_dir = '$GenX_xQC.options.work_dir/$git_Repo_dir_X'
	if os.dir_exists(repo_dir) {
		GenX_xQC.logger.info('Purging local repo: "$repo_dir"')
		GenX_xQC.cmd_exec('rm -rf $repo_dir')
	}
    */
}

// Check if file size is too short
fn (GenX_xQC mut GenXQC) assert_file_exists_and_is_not_too_short(f string, emsg string){
	if !os.file_exists(f) {
		GenX_xQC.logger.error('$err_msg_build: $emsg .')
		GenX_xQC.gen_error = true
		return
	}
	fsize := os.file_size(f)
	if fsize < too_short_filesize_limit {
		GenX_xQC.logger.error('$err_msg_build: $f exists, but is too short: only $fsize bytes.')
		GenX_xQC.gen_error = true
		return
	}
}