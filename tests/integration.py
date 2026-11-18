import argparse
import ctypes as c
from pathlib import Path
import shutil


class Traits(c.Structure):
    _fields_ = [
        ('data_size', c.c_int),
        *[(name, c.c_char_p) for name in (
            'shared_data_dir', 'user_data_dir', 'distribution_name',
            'distribution_code_name', 'distribution_version', 'app_name',
        )],
        ('modules', c.POINTER(c.c_char_p)), ('min_log_level', c.c_int),
        ('log_dir', c.c_char_p), ('prebuilt_data_dir', c.c_char_p),
        ('staging_dir', c.c_char_p),
    ]


class Commit(c.Structure):
    _fields_ = [('data_size', c.c_int), ('text', c.c_char_p)]


class Composition(c.Structure):
    _fields_ = [(name, c.c_int) for name in ('length', 'cursor_pos', 'sel_start', 'sel_end')]
    _fields_.append(('preedit', c.c_char_p))


class Menu(c.Structure):
    _fields_ = [(name, c.c_int) for name in (
        'page_size', 'page_no', 'is_last_page', 'highlighted_candidate_index', 'num_candidates',
    )]
    _fields_ += [('candidates', c.c_void_p), ('select_keys', c.c_char_p)]


class Context(c.Structure):
    _fields_ = [
        ('data_size', c.c_int), ('composition', Composition), ('menu', Menu),
        ('commit_text_preview', c.c_char_p), ('select_labels', c.c_void_p),
    ]


class RimeAPI(c.Structure):
    _fields_ = [('data_size', c.c_int)]
    _fields_ += [(name, c.c_void_p) for name in '''
        setup set_notification_handler initialize finalize start_maintenance is_maintenance_mode
        join_maintenance_thread deployer_initialize prebuild deploy deploy_schema deploy_config_file
        sync_user_data create_session find_session destroy_session cleanup_stale_sessions
        cleanup_all_sessions process_key commit_composition clear_composition get_commit free_commit
        get_context free_context get_status free_status set_option get_option set_property get_property
        get_schema_list free_schema_list get_current_schema select_schema
    '''.split()]


def versioned(value_type):
    value = value_type()
    value.data_size = c.sizeof(value) - c.sizeof(c.c_int)
    return value


def run(args):
    root = Path(__file__).resolve().parents[1]
    workspace = args.work_dir.resolve()
    workspace.mkdir(parents=True, exist_ok=False)
    shutil.copytree(root / 'rime', workspace, dirs_exist_ok=True)
    (workspace / 'default.custom.yaml').write_text(
        'patch:\n  schema_list:\n    - schema: vi_keyboard\n', encoding='utf-8',
    )
    rime = c.CDLL(str(args.library.resolve()), mode=c.RTLD_GLOBAL)
    if args.lua_module:
        lua_module = c.CDLL(str(args.lua_module.resolve()), mode=c.RTLD_GLOBAL)
    rime.rime_get_api.restype = c.POINTER(RimeAPI)
    api = rime.rime_get_api().contents

    def bind(name, result, *arguments):
        return c.CFUNCTYPE(result, *arguments)(getattr(api, name))

    session_type = c.c_size_t
    traits = versioned(Traits)
    traits.shared_data_dir = str(args.shared_data.resolve()).encode()
    traits.user_data_dir = str(workspace).encode()
    traits.app_name = b'rime.vi-keyboard-integration'
    traits.log_dir = b''
    traits.min_log_level = 2
    traits.modules = (c.c_char_p * 4)(b'default', b'deployer', b'lua', None)
    bind('setup', None, c.POINTER(Traits))(c.byref(traits))
    bind('initialize', None, c.POINTER(Traits))(c.byref(traits))
    try:
        assert bind('deploy', c.c_int)(), 'Rime deployment failed'
        session = bind('create_session', session_type)()
        assert session, 'Rime did not create a session'
        assert bind('select_schema', c.c_int, session_type, c.c_char_p)(session, b'vi_keyboard')
        process_key = bind('process_key', c.c_int, session_type, c.c_int, c.c_int)
        get_commit = bind('get_commit', c.c_int, session_type, c.POINTER(Commit))
        free_commit = bind('free_commit', c.c_int, c.POINTER(Commit))
        get_context = bind('get_context', c.c_int, session_type, c.POINTER(Context))
        free_context = bind('free_context', c.c_int, c.POINTER(Context))
        clear = bind('clear_composition', None, session_type)

        def key(code, mask=0):
            handled = bool(process_key(session, code, mask))
            commit = versioned(Commit)
            text = ''
            if get_commit(session, c.byref(commit)):
                text = commit.text.decode('utf-8')
                free_commit(c.byref(commit))
            return handled, text

        def type_text(text):
            output = []
            for character in text:
                handled, committed = key(ord(character), int(character.isupper()))
                output.append(committed)
                if not handled:
                    output.append(character)
            return ''.join(output)

        cases = 0
        failures = []
        for line in (root / 'tests' / 'typing.tsv').read_text(encoding='utf-8').splitlines():
            if not line or line.startswith('#'):
                continue
            source, _, expected = line.partition('\t')
            expected = expected or source
            actual = type_text(source + ' ')
            expected += ' '
            if actual != expected:
                failures.append(f'{source!r} produced {actual!r}, expected {expected!r}')
            cases += 1

        assert not failures, '\n'.join(failures)
        assert type_text('vieejt') == ''
        context = versioned(Context)
        assert get_context(session, c.byref(context))
        try:
            assert context.composition.preedit.decode('utf-8').rstrip() == 'việt'
        finally:
            free_context(c.byref(context))
        assert key(0xff08) == (True, '')  # Backspace
        assert key(0xff0d) == (False, 'việ')  # Enter
        for code, mask in [(0xff09, 0), (0xff51, 0), (ord('c'), 4), (ord('v'), 4), (ord('s'), 8)]:
            assert type_text('tieengs') == ''
            assert key(code, mask) == (False, 'tiếng'), (code, mask)
        assert type_text('vieejt') == ''
        assert key(0xff1b) == (True, '')  # Escape
        assert key(0xff1b) == (False, '')
        assert type_text('as') == ''
        assert key(0xffe1, 1) == (False, '')  # Shift down
        assert key(ord(' '), 1) == (True, 'á ')
        assert key(0xffe1, 1 << 30) == (False, '')  # Shift up
        assert type_text('aw') == ''
        assert key(ord(' '), 1) == (True, 'ă ')
        assert type_text('dd') == ''
        assert key(ord(' '), 1) == (True, 'đ ')
        assert type_text('x' * 64 + 'vieejt ') == 'x' * 64 + 'vieejt '
        assert type_text('vieejt ') == 'việt '
        clear(session)
        assert key(ord(' '), 5) == (True, '')
        assert type_text('vieejt ') == 'vieejt '
        assert key(ord(' '), 5) == (True, '')
        assert type_text('vieejt ') == 'việt '
        print(f'Passed {cases} typing cases plus preedit, editing, shortcuts, and English mode.')
    finally:
        bind('finalize', None)()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for option in ('library', 'shared-data', 'work-dir'):
        parser.add_argument('--' + option, required=True, type=Path)
    parser.add_argument('--lua-module', type=Path)
    run(parser.parse_args())
