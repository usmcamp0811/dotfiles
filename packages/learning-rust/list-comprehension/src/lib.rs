use comp_macro::comp;
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = comp![x for x in [1,2,3]].collect::<Vec<_>>();
        assert_eq!(result.iter().map(|&x| x).collect::<Vec<_>>(), vec![1, 2, 3]);
    }

    #[test]
    fn if_even_test() {
        let ifresult = comp![x for x in [1,2,3,4] if x % 2 == 0].collect::<Vec<_>>();
        assert_eq!(ifresult.iter().map(|&x| x).collect::<Vec<_>>(), vec![2, 4]);
    }

    #[test]
    fn if_odd_test() {
        let result = comp![x for x in 1..10 if x % 2 != 0].collect::<Vec<_>>();
        assert_eq!(
            result.iter().map(|&x| x).collect::<Vec<_>>(),
            vec![1, 3, 5, 7, 9]
        );
    }

    #[test]
    fn if_if_test() {
        let result = comp![x for x in 1..100 if x % 2 != 0 if x < 10].collect::<Vec<_>>();
        assert_eq!(
            result.iter().map(|&x| x).collect::<Vec<_>>(),
            vec![1, 3, 5, 7, 9]
        );
    }
}
