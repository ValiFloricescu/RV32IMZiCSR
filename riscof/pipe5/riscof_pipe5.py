import os
import logging
import riscof.utils as utils
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()

# ============================================================
#  riscof_pipe5.py  -  Plugin riscof pentru DUT-ul pipe5 (RV32IM)
# ------------------------------------------------------------
#  Compileaza fiecare test din riscv-arch-test cu toolchain-ul,
#  apoi il ruleaza pe nucleu prin run_dut.sh (Icarus + tb_compliance)
#  si lasa fisierul de semnatura pe care riscof il compara cu referinta
#  (Sail/Spike). Structura urmeaza sablonul oficial de plugin.
# ============================================================
class pipe5(pluginTemplate):
    __model__ = "pipe5"
    __version__ = "1.0.0"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        config = kwargs.get('config')
        if config is None:
            logger.error("Lipseste nodul de configurare pentru pipe5.")
            raise SystemExit(1)

        self.pluginpath  = os.path.abspath(config['pluginpath'])
        self.isa_spec    = os.path.abspath(config['ispec'])
        self.platform_spec = os.path.abspath(config['pspec'])
        self.num_jobs    = str(config.get('jobs', 1))
        # radacina proiectului (rtl/ + test/) ca s-o stie run_dut.sh
        self.pipe5_root  = os.path.abspath(config.get('pipe5_root', '.'))
        self.target_run  = config.get('target_run', '1') == '1'

    def initialise(self, suite, work_dir, archtest_env):
        self.work_dir = work_dir
        self.suite_dir = suite
        # comanda de compilare a unui test (toolchain RISC-V)
        self.compile_cmd = (
            'riscv32-unknown-elf-gcc -march={0} -mabi=ilp32 '
            '-static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles '
            '-T ' + self.pluginpath + '/env/link.ld '
            '-I ' + self.pluginpath + '/env/ '
            '-I ' + archtest_env + ' {1} -o {2} {3}'
        )

    def build(self, isa_yaml, platform_yaml):
        ispec = utils.load_yaml(isa_yaml)['hart0']
        self.xlen = ('64' if 64 in ispec['supported_xlen'] else '32')
        # construieste sirul -march din ISA suportat
        march = ispec['ISA'].lower()
        # gcc accepta zicsr/zifencei explicit
        self.march = march.replace('zicsr', '_zicsr').replace('zifencei', '_zifencei')
        if 'zicsr' in march and '_zicsr' not in self.march:
            self.march = march
        logger.info("pipe5: march = %s" % self.march)

    def runTests(self, testList):
        for testname in testList:
            testentry = testList[testname]
            test     = testentry['test_path']
            test_dir = testentry['work_dir']
            elf      = os.path.join(test_dir, 'dut.elf')
            sig_file = os.path.join(test_dir, self.name[:-1] + ".signature")

            macros = ' -D' + " -D".join(testentry['macros'])
            cmd = self.compile_cmd.format(testentry['isa'].lower(), test, elf, macros)
            run = (
                'cd {0}; {1}; '
                'PIPE5_ROOT={2} bash {3}/run_dut.sh {4} {0} {5}'
            ).format(test_dir, cmd, self.pipe5_root, self.pluginpath, elf, sig_file)

            if self.target_run:
                utils.shellCommand(run).run()
            else:
                utils.shellCommand(cmd).run()  # doar compilare (dry-run)