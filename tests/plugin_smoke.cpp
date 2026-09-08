// Native plugin/SPI smoke test. It does not substitute for execution in Stata.
#include "stplugin.h"
#include <algorithm>
#include <cmath>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>
#ifdef _WIN32
#include <windows.h>
// The SDK declares an exported pginit; this host stub is never called.
STDLL pginit(ST_plugin*) { return SD_PLUGINVER; }
#else
#include <dlfcn.h>
#endif

namespace {
using Columns = std::vector<std::vector<double>>;
Columns data;
std::map<std::string, double> scalars;
std::string error;
int stop = 0;
int rows() { return static_cast<int>(data.at(0).size()); }
int vars() { return static_cast<int>(data.size()); }
int first() { return 1; }
ST_boolean selected(int) { return 1; }
int output(char*) { return 0; }
int report_error(char* message) { error = message; return 0; }
int read_value(int v, int r, double* value) {
    if (v < 1 || v > vars() || r < 1 || r > rows()) return 198;
    *value = data[static_cast<std::size_t>(v - 1)][static_cast<std::size_t>(r - 1)];
    return 0;
}
int write_value(int v, int r, double value) {
    if (v < 1 || v > vars() || r < 1 || r > rows()) return 198;
    data[static_cast<std::size_t>(v - 1)][static_cast<std::size_t>(r - 1)] = value;
    return 0;
}
int scalar_save(char* name, double value) { scalars[name] = value; return 0; }
void require(bool ok, const std::string& why) { if (!ok) throw std::runtime_error(why); }
double scalar(const char* name) { return scalars.at(std::string("probe_") + name); }
using Call = ST_retcode (*)(int, char*[]);

void run(Call call, Columns input, const std::string& config, int threads) {
    data = std::move(input); scalars.clear(); error.clear();
    std::string args = "cfg=" + config + ";num_threads=" + std::to_string(threads) + ";s_prefix=probe_;";
    char* argv[] = {args.data()};
    int rc = call(1, argv);
    require(rc == 0, "plugin error " + std::to_string(rc) + ": " + error);
    require(scalar("openmp_enabled") == 1, "production plugin has no OpenMP");
    require(scalar("threads_used") == std::min<double>(threads, scalar("thread_capacity")), "requested team was not observed");
}
}

int main(int argc, char** argv) {
    try {
        require(argc == 2, "usage: plugin_smoke /absolute/path/to/xsamplefe.plugin");
#ifdef _WIN32
        HMODULE library = LoadLibraryA(argv[1]);
        require(library != nullptr, "LoadLibrary failed: " + std::to_string(GetLastError()));
        auto init = reinterpret_cast<ST_retcode (*)(ST_plugin*)>(GetProcAddress(library, "pginit"));
        auto call = reinterpret_cast<Call>(GetProcAddress(library, "stata_call"));
#else
        void* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) throw std::runtime_error(dlerror());
        auto init = reinterpret_cast<ST_retcode (*)(ST_plugin*)>(dlsym(library, "pginit"));
        auto call = reinterpret_cast<Call>(dlsym(library, "stata_call"));
#endif
        require(init && call, "plugin entry points missing");
        ST_plugin api{};
        api.spoutsml = output; api.spouterr = report_error;
        api.safevdata = read_value; api.vdata = read_value;
        api.safestore = write_value; api.store = write_value;
        api.scalsave = scalar_save;
        api.nobs = rows; api.nvar = vars; api.nvars = vars;
        api.nobs1 = first; api.nobs2 = rows; api.selobs = selected;
        api.missval = 8.0e307; api.stopflag = &stop;
        require(init(&api) == SD_PLUGINVER, "unexpected SPI version");
        const std::string obs = "is_count=0;pct=50;has_unit=0;nby=0;has_time=0;has_mob=0;has_group=0;nu=2";
        const std::vector<double> keys{.9,.1,.8,.2,.7,.3,.6,.4,.5,.0};
        for (int threads : {1, 8}) {
            run(call, {std::vector<double>(10,1),keys,std::vector<double>(10,.5),std::vector<double>(10,7)}, obs, threads);
            require(data.back() == std::vector<double>({0,1,0,1,0,1,0,1,0,1}), "observation selection differs from smallest keys");
            require(scalar("N_retained") == 5, "observation count mismatch");
            Columns unit{std::vector<double>(12,1),{10,10,10,20,20,20,30,30,30,40,40,40},
                         {1,2,3,1,2,3,1,2,3,1,2,3},{1,1,1,1,2,2,3,3,3,2,3,3},
                         {.9,.1,.8,.2,.7,.3,.6,.4,.5,.0,.11,.12},std::vector<double>(12,.5),std::vector<double>(12,7)};
            const std::string cfg = "is_count=0;pct=50;has_unit=1;nby=0;has_time=1;has_mob=1;has_group=0;nu=2;connected=1";
            run(call, unit, cfg, threads);
            require(data.back() == std::vector<double>({0,0,0,1,1,1,0,0,0,1,1,1}), "whole-unit selection mismatch");
            require(scalar("U_selected") == 2 && scalar("C_sample") == 1, "unit/graph diagnostics mismatch");
            for (int column : {0,1,2,3}) std::reverse(unit[column].begin(), unit[column].end());
            run(call, unit, cfg, threads);
            require(data.back() == std::vector<double>({1,1,1,0,0,0,1,1,1,0,0,0}), "unit result depends on row order");
            run(call, {std::vector<double>(8,1),{1,1,2,2,3,3,4,4},{1,2,2,3,3,4,4,1},
                       {.9,.1,.8,.2,.7,.3,.6,.4},std::vector<double>(8,.5),std::vector<double>(8,7)},
                "is_count=0;pct=25;has_unit=1;nby=0;has_time=0;has_mob=0;has_group=1;nu=2", threads);
            require(data.back() == std::vector<double>({0,1,1,1,1,0,0,0}), "group closure mismatch");
            require(scalar("U_partial") == 2 && scalar("G_kept") == 2, "group diagnostics mismatch");
            run(call, Columns(4), obs, threads);
            require(scalar("N_total") == 0 && scalar("N_retained") == 0, "empty-frame mismatch");
        }
        std::cout << "XSAMPLEFE NATIVE PLUGIN SPI TEST PASSED\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
