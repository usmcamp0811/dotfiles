use comp_macro::comp;
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = comp![x for x in [1,2,3]].collect::<Vec<_>>();
        assert_eq!(result.iter().map(|&x| x).collect::<Vec<_>>(), vec![1, 2, 3]);
    }
}
