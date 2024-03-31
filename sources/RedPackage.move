module admin::RedPackage {

    use std::signer;
    use std::string::{String, utf8};
    use std::vector;
    use std::vector::partition;
    use aptos_std::math64::max;
    use aptos_std::table;
    use aptos_std::table::Table;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::coin::{BurnCapability, Coin};
    use aptos_framework::timestamp;

    // public entry fun hehe() {
    //
    // }
    //
    // public entry fun sao(sender:&signer,  recipent: address, amount:u64) {
    //     // coin::transfer<AptosCoin>(sender, recipent, amount);
    //     aptos_account::transfer_coins<AptosCoin>(sender, recipent, amount)
    // }

    // struct MoneyOne {
    //
    // }
    //
    // struct CoinBurnCap has key {
    //     burn_cap: coin::BurnCapability<MoneyOne>,
    //     freez_cap: coin::FreezeCapability<MoneyOne>,
    //     mint_cap: coin::MintCapability<MoneyOne>
    // }

    // public entry fun money_one_init(sender: &signer) {
    //   let (a,b,c) =  coin::initialize<MoneyOne>(sender,
    //         utf8(b"MoneyOne"),
    //         utf8(b"MOC"),
    //         8,
    //         true);
    //
    //     move_to(sender, CoinBurnCap{
    //         burn_cap: a,
    //         freez_cap: b,
    //         mint_cap: c
    //     });
    // }
    // struct Vec has key {
    //     list: vector<address>
    // }

    // public entry fun setWhiteList(sender: &signer, addrs: vector<address>) acquires Vec {
    //     assert!(signer::address_of(sender) == @admin, 1);
    //
    //
    //     if(!exists<Vec>(@admin)){
    //         move_to(sender, Vec {
    //             list: vector::empty()
    //         });
    //     };
    //
    //     let list =  &mut borrow_global_mut<Vec>(@admin).list;
    //     vector::append(list, addrs);
    //
    //
    // }
    //
    // public entry fun mint(sender:&signer, amount: u64) acquires CoinBurnCap {
    //     assert!(signer::address_of(sender) == @admin, 1);
    //
    //
    //    let coin = coin::mint(amount, &borrow_global<CoinBurnCap>(@admin).mint_cap);
    //     aptos_account::deposit_coins(signer::address_of(sender), coin);
    // }


    struct RedPackageList has key {
        list: vector<RedPackage>
    }

    struct RedPackage has key, store {
        creator: address,
        name: String,
        partition: u64,
        partition_claimed: u64,
        balance:u64,
        coin: Coin<AptosCoin>,
    }

    public entry fun initRedPackage(sender:&signer) {
        assert!(signer::address_of(sender) == @admin, 3);
        assert!(!exists<RedPackageList>(@admin), 1);
        
        move_to(sender, RedPackageList{
            list: vector::empty<RedPackage>()
        })
    }

    public entry fun createRedPackage(sender:&signer, name:String, amount:u64, partition:u64) acquires RedPackageList {
        
        assert!(exists<RedPackageList>(@admin), 1);
        assert!(coin::balance<AptosCoin>(signer::address_of(sender)) > amount, 11);
        
        let mutList = &mut borrow_global_mut<RedPackageList>(@admin).list;
        let coin = coin::withdraw<AptosCoin>(sender, amount);
        vector::push_back(mutList, RedPackage{
            creator: signer::address_of(sender),
            partition,
            partition_claimed: 0,
            name,
            balance: amount,
            coin
        });
    }

    public entry fun unpackRedPackage(sender:&signer, index:u64) acquires RedPackageList {
        assert!(exists<RedPackageList>(@admin), 1);

        let list = &borrow_global<RedPackageList>(@admin).list;
        let redPackage = vector::borrow<RedPackage>(list,index);
        let remainAmountInRedPackage = coin::value(&redPackage.coin);
        assert!(remainAmountInRedPackage > 0  , 13);


        let mutList = &mut borrow_global_mut<RedPackageList>(@admin).list;
        let mutRedPackage = vector::borrow_mut<RedPackage>(mutList, index);

        assert!(mutRedPackage.partition > mutRedPackage.partition_claimed, 10);

        if(mutRedPackage.partition - mutRedPackage.partition_claimed > 1) {
            let percent = max(timestamp::now_seconds() % 100 *  remainAmountInRedPackage, 50) / 100;
            let partitionCoin = coin::extract(&mut mutRedPackage.coin, percent);
            aptos_account::deposit_coins(signer::address_of(sender), partitionCoin);

        }else {
            let extractedCoin = coin::extract(&mut mutRedPackage.coin, remainAmountInRedPackage);
            aptos_account::deposit_coins(signer::address_of(sender), extractedCoin);
        };

        mutRedPackage.partition_claimed =  mutRedPackage.partition_claimed + 1
    }

    public entry fun batchUnpackageRedPackage(sender:signer, index:u64, times:u64) acquires RedPackageList {
        for(i in 0..times) {
            unpackRedPackage(&sender, index);
        }
    }

    #[view]
    public fun redPackage(index:u64):(address, String, u64, u64, u64, u64) acquires RedPackageList {
        assert!(exists<RedPackageList>(@admin), 1);

        let redPackageList = &borrow_global<RedPackageList>(@admin).list;
        let RedPackage{
            creator,
            name,
            partition,
            partition_claimed,
            balance,
            coin,
        } = vector::borrow<RedPackage>(redPackageList, index);

        (
            *creator,
            *name,
            *partition,
            *partition_claimed,
            *balance,
            coin::value(coin),
        )
    }

    #[view]
    public fun redPackageTotal():u64 acquires RedPackageList {
        assert!(exists<RedPackageList>(@admin), 1);
        vector::length(&borrow_global<RedPackageList>(@admin).list)
    }
}
