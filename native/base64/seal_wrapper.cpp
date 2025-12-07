// native/seal_wrapper.cpp
#include "seal/seal.h"
#include "base64.h"
#include <fstream>
#include <string>
#include <iostream>
#include <vector>
#include <sstream>
#include <cstring> // memcpy를 위해 추가

using namespace std;
using namespace seal;

// C++ 이름 맹글링 방지
extern "C" {

    // 키 생성 및 저장 함수
    void generate_keys(const char* output_dir, int degree) {
        string dir(output_dir);

        // 1. 파라미터 설정 (BFV)
        EncryptionParameters parms(scheme_type::bfv);
        size_t poly_modulus_degree = degree;
        parms.set_poly_modulus_degree(poly_modulus_degree);
        parms.set_coeff_modulus(CoeffModulus::BFVDefault(poly_modulus_degree));
        parms.set_plain_modulus(PlainModulus::Batching(poly_modulus_degree, 20));

        SEALContext context(parms);

        // 2. 키 생성
        KeyGenerator keygen(context);
        SecretKey secret_key = keygen.secret_key();
        PublicKey public_key;
        keygen.create_public_key(public_key);
        RelinKeys relin_keys;
        keygen.create_relin_keys(relin_keys);
        GaloisKeys gal_keys;
        keygen.create_galois_keys(gal_keys);

        // 3. 파일로 저장
        ofstream sk_fs(dir + "/secret_key.k", ios::binary);
        secret_key.save(sk_fs);

        ofstream pk_fs(dir + "/public_key.k", ios::binary);
        public_key.save(pk_fs);

        ofstream rlk_fs(dir + "/relin_keys.k", ios::binary);
        relin_keys.save(rlk_fs);

        ofstream galk_fs(dir + "/gal_keys.k", ios::binary);
        gal_keys.save(galk_fs);
    }
    
    // 메모리 상의 SK를 이용해 검색 결과(암호문) 복호화
    int decrypt_score_memory(const char* enc_score_base64, const char* sk_bytes, int sk_size) {
        try {
            EncryptionParameters parms(scheme_type::bfv);
            size_t poly_modulus_degree = 8192;
            parms.set_poly_modulus_degree(poly_modulus_degree);
            parms.set_coeff_modulus(CoeffModulus::BFVDefault(poly_modulus_degree));
            parms.set_plain_modulus(PlainModulus::Batching(poly_modulus_degree, 20));
            SEALContext context(parms);

            SecretKey secret_key;
            string sk_str(sk_bytes, sk_size);
            stringstream sk_stream(sk_str);
            secret_key.load(context, sk_stream);

            Decryptor decryptor(context, secret_key);
            BatchEncoder batch_encoder(context);

            string enc_data = base64_decode(string(enc_score_base64));
            stringstream enc_stream(enc_data);
            Ciphertext result_ct;
            result_ct.load(context, enc_stream);

            Plaintext result_pt;
            decryptor.decrypt(result_ct, result_pt);

            vector<int64_t> result_vec;
            batch_encoder.decode(result_pt, result_vec);

            if (result_vec.empty()) return -1;
            return (int)result_vec[0];

        } catch (const exception& e) {
            cerr << "Decryption Error: " << e.what() << endl;
            return -1;
        }
    }

    // [NEW] 인덱스 벡터 암호화 함수
    // vec: 0/1 정수 배열 포인터
    // vec_len: 벡터 길이
    // out_buf: 암호문 저장할 버퍼
    // out_max_len: 버퍼 최대 크기
    // keys_dir: 공개키가 저장된 폴더 경로
    int encrypt_vector(int* vec, int vec_len, char* out_buf, int out_max_len, const char* keys_dir) {
        try {
            // 1. 파라미터 설정 (8192, BFV)
            EncryptionParameters parms(scheme_type::bfv);
            size_t poly_modulus_degree = 8192;
            parms.set_poly_modulus_degree(poly_modulus_degree);
            parms.set_coeff_modulus(CoeffModulus::BFVDefault(poly_modulus_degree));
            parms.set_plain_modulus(PlainModulus::Batching(poly_modulus_degree, 20));
            SEALContext context(parms);

            // 2. 공개키 로드
            PublicKey public_key;
            string path = string(keys_dir) + "/public_key.k";
            ifstream pk_fs(path, ios::binary);
            if (!pk_fs.is_open()) {
                cerr << "Failed to open public key at: " << path << endl;
                return -1;
            }
            public_key.load(context, pk_fs);

            // 3. 도구 준비
            BatchEncoder batch_encoder(context);
            Encryptor encryptor(context, public_key);

            // 4. int* -> vector<int64_t> 변환
            vector<int64_t> pod_matrix;
            pod_matrix.reserve(vec_len);
            for (int i = 0; i < vec_len; i++) {
                pod_matrix.push_back((int64_t)vec[i]);
            }
            
            // 슬롯 크기에 맞게 패딩 (남는 공간 0으로 채움)
            size_t slot_count = batch_encoder.slot_count();
            if (pod_matrix.size() < slot_count) {
                pod_matrix.resize(slot_count, 0);
            }

            // 5. 인코딩 & 암호화
            Plaintext plain_matrix;
            batch_encoder.encode(pod_matrix, plain_matrix);

            Ciphertext encrypted;
            encryptor.encrypt(plain_matrix, encrypted);

            // 6. 직렬화 (메모리 스트림에 저장)
            stringstream ss;
            encrypted.save(ss); // 기본 압축 사용
            string str = ss.str();

            // 7. 결과 복사
            if (str.size() > (size_t)out_max_len) {
                cerr << "Output buffer too small (" << out_max_len << " < " << str.size() << ")" << endl;
                return -1;
            }

            memcpy(out_buf, str.c_str(), str.size());
            return (int)str.size(); // 쓴 바이트 수 반환

        } catch (const exception& e) {
            cerr << "Encryption Error: " << e.what() << endl;
            return -1;
        }
    }
}