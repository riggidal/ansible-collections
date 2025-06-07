import pytest

###############################################################################
# 1.  Описываем, как “логическое” имя пакета мапится на:
#       • package-name в системе,
#       • бинарь (для smoke-run),
#       • service (если должен работать).
###############################################################################
PKG_DATA = {
    "htop": {
        "pkg": {
            "Debian":  "htop",
            "Ubuntu":  "htop",
            "RedHat":  "htop",
        },
        "bin": "htop",
    },
    "podman": {
        "pkg": {
            "Debian":  "podman",
            "Ubuntu":  "podman",
            "RedHat":  "podman",
        },
        "bin": "podman",
    },
    "nginx": {
        "pkg": {
            "Debian":  "nginx",
            "Ubuntu":  "nginx",
            "RedHat":  "nginx",
        },
        "service": "nginx",
    },
}

###############################################################################
# 2.  Достаём список пакетов из host-vars, превращаем в data-driven набор тестов
###############################################################################
def pytest_generate_tests(metafunc):
    if "pkg_name" in metafunc.fixturenames:
        host = metafunc.config._host
        wanted = host.ansible.get_variables().get("packages", [])
        metafunc.parametrize("pkg_name", wanted, ids=wanted)


###############################################################################
# 3.  Собственно тесты
###############################################################################
def _get_real_pkg_name(host, logical_name):
    """Возвращает имя пакета для данной ОС."""
    osfam = host.system_info.distribution.lower()
    fam = "Debian" if osfam in ("debian", "ubuntu") else "RedHat"
    return PKG_DATA[logical_name]["pkg"][fam]


def test_package_installed(host, pkg_name):
    real = _get_real_pkg_name(host, pkg_name)
    assert host.package(real).is_installed


def test_binary_available(host, pkg_name):
    bin_name = PKG_DATA[pkg_name].get("bin")
    if bin_name:
        assert host.exists(bin_name)


def test_service_running(host, pkg_name):
    svc = PKG_DATA[pkg_name].get("service")
    if svc and host.ansible.get_variables().get("ansible_service_mgr") == "systemd":
        service = host.service(svc)
        assert service.is_running
        assert service.is_enabled
