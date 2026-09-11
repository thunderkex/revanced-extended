pub fn check_compatibility(app_version: &str, min: Option<&str>, max: Option<&str>) -> bool {
    let app_v = clean_version(app_version);
    if let Some(min_v) = min {
        if !min_v.is_empty() && app_v < clean_version(min_v) {
            return false;
        }
    }
    if let Some(max_v) = max {
        if !max_v.is_empty() && app_v > clean_version(max_v) {
            return false;
        }
    }
    true
}

fn clean_version(v: &str) -> String {
    v.trim_start_matches('v')
        .split('-')
        .next()
        .unwrap_or(v)
        .to_string()
}
