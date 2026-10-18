// SECCION: MAIN DISPATCH
// IPC: apply next prev stop pause resume toggle status list browse capabilities
fn main() {
    let args: Vec<String> = std::env::args().collect();
    std::process::exit(oozewalls::cli::run(&args));
}
